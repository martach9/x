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

my $nueva_direccion =
    $cgi->param('nueva_direccion') || '';

$nueva_direccion =~ s/^\s+|\s+$//g;

# =========================================================
# MOSTRAR FORMULARIO
# =========================================================

unless ($nueva_direccion) {

    print $cgi->header(
        -type    => 'text/html',
        -charset => 'UTF-8'
    );

    print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Cambiar dirección</title>

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

Cambiar dirección

</h2>

<form
action="/cgi-bin/cambiarDireccion.pl"
method="POST">

<input
type="text"
name="nueva_direccion"
placeholder="Nueva dirección"
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
# COMPROBAR DIRECCION ACTUAL
# =========================================================

my $check = $dbh->prepare(q{

SELECT direccion
FROM usuarios
WHERE login = ?

});

$check->execute($login);

my ($direccion_actual) =
    $check->fetchrow_array();

$check->finish();

# =========================================================
# MISMA DIRECCION
# =========================================================

if (
    defined $direccion_actual
    &&
    $direccion_actual eq $nueva_direccion
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
    color:#ff6b6b;
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

<h2 class="error">

Error

</h2>

<p>

La nueva dirección no puede ser igual a la actual.

</p>

<form
action="/cgi-bin/datosPersonales.pl"
method="GET">

<button type="submit">

Volver

</button>

</form>

</div>

</body>

</html>

    };

    $dbh->disconnect();

    exit;
}

# =========================================================
# ACTUALIZAR DIRECCION
# =========================================================

my $sth = $dbh->prepare(q{

UPDATE usuarios
SET direccion = ?
WHERE login = ?

});

$sth->execute(
    $nueva_direccion,
    $login
);

$sth->finish();

$dbh->disconnect();

# =========================================================
# REDIRECT
# =========================================================

print $cgi->redirect(
    '/cgi-bin/datosPersonales.pl?ok=direccion'
);

exit;
