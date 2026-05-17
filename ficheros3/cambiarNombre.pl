#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use CGI::Carp qw(fatalsToBrowser);
use CGI::Session;

require "/var/www/cgi-bin/conexion.pl";

# =========================================================
# CGI
# =========================================================

my $cgi = CGI->new;

# =========================================================
# SESION
# =========================================================

CGI::Session->name("ECOSESSION");

my $session = CGI::Session->new(
    undef,
    $cgi,
    { Directory => '/var/lib/ecosalmantica/sessions' }
);

unless ($session->param('autenticado')) {

    print $cgi->redirect('/');
    exit;
}

my $login =
    $session->param('usuario') || '';

unless ($login =~ /^[a-z_][a-z0-9_-]{2,31}$/) {

    print $cgi->redirect('/');
    exit;
}

# =========================================================
# PARAMETROS
# =========================================================

my $nuevo_nombre =
    $cgi->param('nuevo_nombre') || '';

$nuevo_nombre =~ s/^\s+|\s+$//g;

# =========================================================
# FORMULARIO
# =========================================================

unless ($nuevo_nombre) {

    print $cgi->header(
        -type    => 'text/html',
        -charset => 'UTF-8'
    );

    print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Cambiar nombre</title>

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
}

button{
    background:#1ab188;
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

Cambiar nombre

</h2>

<form
action="/cgi-bin/cambiarNombre.pl"
method="POST">

<input
type="text"
name="nuevo_nombre"
placeholder="Nuevo nombre"
required>

<button type="submit">

Guardar cambios

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
# COMPROBAR NOMBRE ACTUAL
# =========================================================

my $check = $dbh->prepare(q{

SELECT nombre
FROM usuarios
WHERE login = ?

});

$check->execute($login);

my ($nombre_actual) =
    $check->fetchrow_array();

$check->finish();

# =========================================================
# MISMO NOMBRE
# =========================================================

if (
    defined $nombre_actual
    &&
    $nombre_actual eq $nuevo_nombre
) {

    print $cgi->header(
        -type    => 'text/html',
        -charset => 'UTF-8'
    );

    print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Error</title>

</head>

<body>

<h2>

Error

</h2>

<p>

El nuevo nombre no puede ser igual al actual.

</p>

<a href="/cgi-bin/datosPersonales.pl">

Volver

</a>

</body>

</html>

    };

    $dbh->disconnect();

    exit;
}

# =========================================================
# ACTUALIZAR
# =========================================================

my $sth = $dbh->prepare(q{

UPDATE usuarios
SET nombre = ?
WHERE login = ?

});

$sth->execute(
    $nuevo_nombre,
    $login
);

$sth->finish();

$dbh->disconnect();

# =========================================================
# REDIRECT
# =========================================================

print $cgi->redirect(
    '/cgi-bin/datosPersonales.pl?ok=nombre'
);

exit;
