#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard);
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

$login =~ s/^\s+|\s+$//g;

# =========================================================
# VALIDAR LOGIN
# =========================================================

unless (
    $login =~ /^[a-zA-Z0-9._-]+$/
) {

    print "<h2>Login inválido</h2>";

    exit;
}

# =========================================================
# COMPROBAR OPERARIO
# =========================================================

my $dbh =
    conexion::conectar();

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
# ARCHIVO
# =========================================================

my $fh =
    $cgi->upload('manual');

unless ($fh) {

    print "<h2>No se recibió archivo</h2>";

    exit;
}

# =========================================================
# NOMBRE ARCHIVO
# =========================================================

my $filename =
    $cgi->param('manual');

$filename =~ s!.*[\\/]+!!;
$filename =~ s/\s+/_/g;

unless (
    $filename =~ /^[a-zA-Z0-9._()-]+$/
) {

    print "<h2>Nombre de archivo inválido</h2>";

    exit;
}

# =========================================================
# DESTINO
# =========================================================

my $destino =
    "/manuales_smartcity/$filename";

# =========================================================
# GUARDAR
# =========================================================

open(
    my $out,
    '>',
    $destino
) or die "No se pudo guardar archivo";

binmode($out);

while (my $bytes = <$fh>) {

    print $out $bytes;
}

close($out);

chmod(
    0664,
    $destino
);

# =========================================================
# RESPUESTA
# =========================================================

print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Manual subido</title>

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

Archivo subido correctamente

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
