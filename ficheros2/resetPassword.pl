#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use CGI::Carp qw(fatalsToBrowser);

use Digest::SHA qw(sha256_hex);

require "/usr/lib/cgi-bin/conexion.pl";

# =========================================================
# CGI
# =========================================================

my $cgi = CGI->new;

print $cgi->header(
    -type    => 'text/html',
    -charset => 'UTF-8'
);

# =========================================================
# PARAMETROS
# =========================================================

my $token =
    $cgi->param('token') || '';

my $password1 =
    $cgi->param('password1') || '';

my $password2 =
    $cgi->param('password2') || '';

$token =~ s/^\s+|\s+$//g;

# =========================================================
# VALIDAR TOKEN
# =========================================================

unless (
    $token =~ /^[a-f0-9]{64}$/
) {

    print qq{

    <h2>Token inválido</h2>

    };

    exit;
}

# =========================================================
# DB
# =========================================================

my $dbh = conexion::conectar();

# =========================================================
# BUSCAR TOKEN
# =========================================================

my $sth = $dbh->prepare(q{

SELECT
    login,
    password,
    reset_expira
FROM usuarios
WHERE reset_token = ?
AND reset_expira > NOW()

});

$sth->execute($token);

my $user =
    $sth->fetchrow_hashref();

# =========================================================
# TOKEN INVALIDO
# =========================================================

unless ($user) {

    print qq{

    <h2>Error</h2>

    <p>
    El enlace ha expirado
    o no es válido.
    </p>

    };

    exit;
}

# =========================================================
# MOSTRAR FORMULARIO
# =========================================================

unless (
    $password1 &&
    $password2
) {

    print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Nueva contraseña</title>

<style>

body{
    background:#13232f;
    color:white;
    font-family:Arial,sans-serif;
    padding:40px;
}

.card{
    background:#24333e;
    padding:30px;
    border-radius:10px;
    max-width:600px;
    margin:auto;
}

input{
    width:100%;
    padding:12px;
    margin-bottom:20px;
    border:none;
    border-radius:5px;
    font-size:1em;
    box-sizing:border-box;
}

button{
    background:#8e44ad;
    border:none;
    color:white;
    padding:12px 20px;
    border-radius:5px;
    cursor:pointer;
    width:100%;
}

</style>

</head>

<body>

<div class="card">

<h2>

Nueva contraseña

</h2>

<form
action="/cgi-bin/resetPassword.pl"
method="POST">

<input
type="hidden"
name="token"
value="$token">

<input
type="password"
name="password1"
placeholder="Nueva contraseña"
required>

<input
type="password"
name="password2"
placeholder="Repita la contraseña"
required>

<button type="submit">

Cambiar contraseña

</button>

</form>

</div>

</body>

</html>

    };

    exit;
}

# =========================================================
# VALIDAR IGUALES
# =========================================================

unless (
    $password1 eq $password2
) {

    print qq{

    <h2>Error</h2>

    <p>
    Las contraseñas no coinciden.
    </p>

    };

    exit;
}

# =========================================================
# LONGITUD
# =========================================================

unless (
    length($password1) >= 8
) {

    print qq{

    <h2>Error</h2>

    <p>
    La contraseña debe tener
    al menos 8 caracteres.
    </p>

    };

    exit;
}

# =========================================================
# MISMA PASSWORD
# =========================================================

unless (

    crypt(
        $password1,
        $user->{password}
    ) ne $user->{password}

) {

    print qq{

    <h2>Error</h2>

    <p>
    La nueva contraseña
    no puede ser igual
    a la anterior.
    </p>

    };

    exit;
}

# =========================================================
# NUEVO HASH
# =========================================================

my $salt =
    substr(
        sha256_hex(rand() . time()),
        0,
        16
    );

my $hash =
    crypt(
        $password1,
        '$6$' . $salt . '$'
    );

# =========================================================
# GUARDAR PASSWORD PENDIENTE
# =========================================================

my $up = $dbh->prepare(q{

UPDATE usuarios
SET
    password_nueva_linux = ?,
    reset_token = NULL,
    reset_expira = NULL,
    passwdPendiente = 1
WHERE login = ?

});

$up->execute(

    $hash,
    $user->{login}

);

# =========================================================
# RESPUESTA
# =========================================================

print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Contraseña actualizada</title>

<style>

body{
    background:#13232f;
    color:white;
    font-family:Arial,sans-serif;
    padding:40px;
}

.card{
    background:#24333e;
    padding:30px;
    border-radius:10px;
    max-width:600px;
    margin:auto;
}

.ok{
    color:#1ab188;
}

</style>

</head>

<body>

<div class="card">

<h2 class="ok">

Contraseña actualizada correctamente

</h2>

<p>

La nueva contraseña será aplicada
en unos instantes por el sistema.

</p>

</div>

</body>

</html>

};

# =========================================================
# FIN
# =========================================================

$up->finish();

$sth->finish();

$dbh->disconnect();
