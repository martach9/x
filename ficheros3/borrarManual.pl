#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard);
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

my $archivo =
    $cgi->param('archivo') || '';

$login   =~ s/^\s+|\s+$//g;
$archivo =~ s/^\s+|\s+$//g;

# =========================================================
# VALIDAR
# =========================================================

unless (
    $login =~ /^[a-zA-Z0-9._-]+$/
) {

    print "<h2>Login inválido</h2>";

    exit;
}

unless (
    $archivo =~ /^[a-zA-Z0-9._-]+$/
) {

    print "<h2>Archivo inválido</h2>";

    exit;
}

# =========================================================
# DB
# =========================================================

my $dbh =
    conexion::conectar();

# =========================================================
# COMPROBAR OPERARIO
# =========================================================

my $sth = $dbh->prepare(q{

SELECT tipo
FROM usuarios
WHERE login = ?

});

$sth->execute($login);

my ($tipo) =
    $sth->fetchrow_array();

$sth->finish();

unless (
    defined $tipo
    && $tipo eq 'operario'
) {

    print "<h2>Acceso denegado</h2>";

    $dbh->disconnect();

    exit;
}

# =========================================================
# RUTA
# =========================================================

my $ruta =
    "/manuales_smartcity/$archivo";

# =========================================================
# EXISTE
# =========================================================

unless (-f $ruta) {

    print "<h2>Archivo no encontrado</h2>";

    exit;
}

# =========================================================
# BORRAR
# =========================================================

unlink($ruta)
    or die "No se pudo borrar archivo";

# =========================================================
# RESPUESTA
# =========================================================

print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Archivo borrado</title>

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

.ok{
    color:#1ab188;
}

a{
    color:#4eb5f1;
}

</style>

</head>

<body>

<div class="card">

<h2 class="ok">

Archivo eliminado correctamente

</h2>

<p>

<a href="/cgi-bin/manuales.pl?login=$login">

Volver a manuales

</a>

</p>

</div>

</body>

</html>

};

# =========================================================
# FIN
# =========================================================

$dbh->disconnect();
