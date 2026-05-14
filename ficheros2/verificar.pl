#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use Unix::Passwd::File;

require "/usr/bin/cgi-bin/conexion.pl";

# =========================================================
# CGI
# =========================================================

my $cgi = CGI->new;

print $cgi->header(
    -type    => 'text/html',
    -charset => 'UTF-8'
);

# =========================================================
# TOKEN
# =========================================================

my $token = $cgi->param('token') || '';

# =========================================================
# VALIDAR TOKEN
# =========================================================

unless (
    $token =~ /^[a-fA-F0-9]{32,128}$/
) {

    print qq{

<!DOCTYPE html>

<html lang="es">

<head>
<meta charset="UTF-8">
<title>Error</title>

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

.error{
    color:#e74c3c;
}

</style>

</head>

<body>

<div class="card">

<h2 class="error">

Token inválido

</h2>

<p>

El enlace de verificación no es válido.

</p>

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
    activo,
    tipo
FROM usuarios
WHERE token = ?

});

$sth->execute($token);

my (
    $login,
    $activo,
    $tipo
) = $sth->fetchrow_array();

# =========================================================
# TOKEN NO EXISTE
# =========================================================

unless ($login) {

    print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Error</title>

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

.error{
    color:#e74c3c;
}

</style>

</head>

<body>

<div class="card">

<h2 class="error">

Token inválido o expirado

</h2>

<p>

La cuenta no puede verificarse.

</p>

</div>

</body>

</html>

};

    $dbh->disconnect();

    exit;
}

# =========================================================
# VALIDAR LOGIN LINUX
# =========================================================

unless (
    $login =~ /^[a-z_][a-z0-9_-]{2,31}$/
) {

    print qq{

<h2>Error crítico</h2>

<p>
Usuario inválido.
</p>

};

    $dbh->disconnect();

    exit;
}

my $login_safe =
    escapeHTML($login);

# =========================================================
# YA ACTIVADO
# =========================================================

if ($activo) {

    print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Cuenta ya activada</title>

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

.success{
    color:#1ab188;
}

a{
    color:#4eb5f1;
}

</style>

</head>

<body>

<div class="card">

<h2 class="success">

Cuenta ya activada

</h2>

<p>

El usuario
<b>$login_safe</b>
ya estaba verificado.

</p>

<br>

<a href="/index.html">

Ir al login

</a>

</div>

</body>

</html>

};

    $dbh->disconnect();

    exit;
}

# =========================================================
# ACTIVAR DB
# =========================================================

eval {

    my $update = $dbh->prepare(q{

    UPDATE usuarios
    SET activo = 1,
        token  = NULL
    WHERE login = ?

    });

    $update->execute($login);
};

if ($@) {

    print qq{

<h2>Error DB</h2>

<p>
No se pudo activar la cuenta.
</p>

};

    $dbh->disconnect();

    exit;
}

# =========================================================
# CAMBIO SHELL LINUX
# =========================================================

my $shell_final =
    ($tipo && $tipo eq 'operario')
    ? '/bin/bash'
    : '/usr/sbin/nologin';

eval {

    my $passwd =
        Unix::Passwd::File->new(
            '/etc/passwd'
        );

    unless ($passwd->user($login)) {

        die "Usuario Linux no existe";
    }

    # =====================================================
    # ACTUALIZAR SHELL
    # =====================================================

    my @user_data =
        $passwd->user($login);

    unless (@user_data) {

        die "No se pudo leer passwd";
    }

    my (
        $name,
        $pass,
        $uid,
        $gid,
        $gecos,
        $home,
        $shell
    ) = @user_data;

    $passwd->delete($login);

    $passwd->add(
        $login,
        $pass,
        $uid,
        $gid,
        $gecos,
        $home,
        $shell_final
    );

    $passwd->commit();
};

# =========================================================
# ERROR LINUX
# =========================================================

if ($@) {

    print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Error Linux</title>

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
    max-width:700px;
    margin:auto;
}

.error{
    color:#e74c3c;
}

pre{
    background:#000;
    padding:10px;
    overflow:auto;
}

</style>

</head>

<body>

<div class="card">

<h2 class="error">

Cuenta activada parcialmente

</h2>

<p>

La cuenta DB fue activada,
pero ocurrió un error Linux.

</p>

<pre>
@{[ escapeHTML($@) ]}
</pre>

</div>

</body>

</html>

};

    $dbh->disconnect();

    exit;
}

# =========================================================
# RESPUESTA OK
# =========================================================

print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Cuenta activada</title>

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
    max-width:700px;
    margin:auto;
}

.success{
    color:#1ab188;
}

code{
    background:#000;
    padding:4px;
}

a{
    color:#4eb5f1;
}

</style>

</head>

<body>

<div class="card">

<h2 class="success">

¡Cuenta activada correctamente!

</h2>

<p>

El usuario
<b>$login_safe</b>
ya puede acceder al sistema.

</p>

<p>

Shell asignada:

<code>$shell_final</code>

</p>

<br>

<a href="/index.html">

Ir al login

</a>

</div>

</body>

</html>

};

# =========================================================
# CERRAR DB
# =========================================================

$dbh->disconnect();
