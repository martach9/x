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
# TOKEN
# =========================================================

my $token = $cgi->param('token') || '';

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
# BUSCAR USUARIO
# =========================================================

my $sth = $dbh->prepare(q{

SELECT login, activo
FROM usuarios
WHERE token = ?

});

$sth->execute($token);

my $row = $sth->fetchrow_hashref();

unless ($row) {

    print qq{
    <h2>Token no válido</h2>
    <p>El enlace de activación no existe.</p>
    };

    exit;
}

# =========================================================
# YA ACTIVADO
# =========================================================

if ($row->{activo}) {

    print qq{
    <h2>Cuenta ya activada</h2>
    };

    exit;
}

# =========================================================
# ACTIVAR
# =========================================================

my $up = $dbh->prepare(q{

UPDATE usuarios
SET activo = 1,
    token = NULL
WHERE token = ?

});

$up->execute($token);

# =========================================================
# RESPUESTA
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
    max-width:600px;
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

Cuenta activada correctamente

</h2>

<p>

Su cuenta ha sido confirmada.

</p>

<p>

En unos minutos el sistema terminará
la creación del usuario Linux.

</p>

<br>

<a href="/index.html">

Volver al login

</a>

</div>

</body>

</html>

};

# =========================================================
# CERRAR DB
# =========================================================

$dbh->disconnect();
