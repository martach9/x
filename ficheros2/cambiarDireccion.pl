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

my $login =
    $cgi->param('login') || '';

my $nueva_direccion =
    $cgi->param('nueva_direccion') || '';

$login =~ s/^\s+|\s+$//g;

$nueva_direccion =~ s/^\s+|\s+$//g;

# =========================================================
# FORMULARIO
# =========================================================

unless ($nueva_direccion) {

    my $login_safe =
        escapeHTML($login);

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
type="hidden"
name="login"
value="$login_safe">

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

# =========================================================
# MISMA DIRECCION
# =========================================================

if (
    defined $direccion_actual
    &&
    $direccion_actual eq $nueva_direccion
) {

    print qq{

    <h2>Error</h2>

    <p>
    La nueva dirección no puede ser igual
    a la actual.
    </p>

    };

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

# =========================================================
# ESCAPAR
# =========================================================

my $direccion_safe =
    escapeHTML($nueva_direccion);

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

<title>Dirección actualizada</title>

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

Dirección actualizada correctamente

</h2>

<p>

Nueva dirección:

<b>$direccion_safe</b>

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
