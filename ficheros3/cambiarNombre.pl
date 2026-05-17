#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use CGI::Carp qw(fatalsToBrowser);

require "/var/www/cgi-bin/conexion.pl";

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

my $login =
    $cgi->param('login') || '';

my $nuevo_nombre =
    $cgi->param('nuevo_nombre') || '';

$login =~ s/^\s+|\s+$//g;

$nuevo_nombre =~ s/^\s+|\s+$//g;

# =========================================================
# FORMULARIO
# =========================================================

unless ($nuevo_nombre) {

    my $login_safe =
        escapeHTML($login);

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
type="hidden"
name="login"
value="$login_safe">

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

# =========================================================
# MISMO NOMBRE
# =========================================================

if (
    defined $nombre_actual
    &&
    $nombre_actual eq $nuevo_nombre
) {

    print qq{

    <h2>Error</h2>

    <p>
    El nuevo nombre no puede ser igual
    al actual.
    </p>

    };

    exit;
}

# =========================================================
# ACTUALIZAR NOMBRE
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

# =========================================================
# ESCAPAR
# =========================================================

my $nombre_safe =
    escapeHTML($nuevo_nombre);

my $login_safe =
    escapeHTML($login);

# =========================================================
# RESPUESTA
# =========================================================

print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Nombre actualizado</title>

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

<h2 class="ok">

Nombre actualizado correctamente

</h2>

<p>

Nuevo nombre:

<b>$nombre_safe</b>

</p>

<br>

<form
action="/cgi-bin/datosPersonales.pl"
method="GET">

<input
type="hidden"
name="login"
value="$login_safe">

<button type="submit">

Volver a datos personales

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
