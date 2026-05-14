#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use CGI::Carp qw(fatalsToBrowser);

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

my $email =
    $cgi->param('email') || '';

my $password =
    $cgi->param('password') || '';

# =========================================================
# SI NO HAY DATOS
# =========================================================

unless (
    $email &&
    $password
) {

    print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Baja de usuario</title>

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
    max-width:500px;
    margin:auto;
}

input{
    width:100%;
    padding:12px;
    margin-bottom:20px;
    border:none;
    border-radius:5px;
    font-size:1em;
}

button{
    background:#c0392b;
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

<h2>Darse de baja</h2>

<p>

Introduzca su correo y contraseña
para continuar.

</p>

<form
action="/cgi-bin/baja.pl"
method="POST">

<input
type="email"
name="email"
placeholder="Correo electrónico"
required>

<input
type="password"
name="password"
placeholder="Contraseña"
required>

<button type="submit">

Continuar

</button>

</form>

</div>

</body>

</html>

    };

    exit;
}

# =========================================================
# DB
# =========================================================

my $dbh = conexion::conectar();

# =========================================================
# BUSCAR USUARIO
# =========================================================

my $sth = $dbh->prepare(q{

SELECT
    login,
    email,
    password,
    activo
FROM usuarios
WHERE email = ?

});

$sth->execute($email);

my $user =
    $sth->fetchrow_hashref();

# =========================================================
# NO EXISTE
# =========================================================

unless ($user) {

    print qq{

    <h2>Error</h2>

    <p>
    El correo no existe.
    </p>

    };

    exit;
}

# =========================================================
# NO ACTIVO
# =========================================================

unless ($user->{activo}) {

    print qq{

    <h2>Error</h2>

    <p>
    La cuenta no está activa.
    </p>

    };

    exit;
}

# =========================================================
# PASSWORD
# =========================================================

unless (
    crypt(
        $password,
        $user->{password}
    ) eq $user->{password}
) {

    print qq{

    <h2>Error</h2>

    <p>
    Contraseña incorrecta.
    </p>

    };

    exit;
}

# =========================================================
# ESCAPAR
# =========================================================

my $login_safe =
    escapeHTML($user->{login});

my $email_safe =
    escapeHTML($user->{email});

# =========================================================
# CONFIRMACION
# =========================================================

print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Confirmar baja</title>

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

button{
    border:none;
    color:white;
    padding:12px 20px;
    border-radius:5px;
    cursor:pointer;
    margin-right:10px;
}

.borrar{
    background:#c0392b;
}

.cancelar{
    background:#1ab188;
}

</style>

</head>

<body>

<div class="card">

<h2>

¿Está seguro?

</h2>

<p>

La cuenta:

<b>$login_safe</b>

será eliminada del sistema.

</p>

<p>

Correo asociado:

<b>$email_safe</b>

</p>

<br>

<form
action="/cgi-bin/procesarBaja.pl"
method="POST">

<input
type="hidden"
name="login"
value="$login_safe">

<button
type="submit"
class="borrar">

Eliminar cuenta

</button>

</form>

<br>

<form
action="/"
method="GET">

<button
type="submit"
class="cancelar">

Cancelar

</button>

</form>

</div>

</body>

</html>

};

# =========================================================
# FIN
# =========================================================

$sth->finish();

$dbh->disconnect();
