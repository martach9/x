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

$login =~ s/^\s+|\s+$//g;

# =========================================================
# VALIDACION
# =========================================================

unless ($login) {

    print qq{

    <h2>Error</h2>

    <p>
    Usuario inválido.
    </p>

    };

    exit;
}

# =========================================================
# DB
# =========================================================

my $dbh = conexion::conectar();

# =========================================================
# MARCAR BAJA
# =========================================================

my $sth = $dbh->prepare(q{

UPDATE usuarios
SET baja = 1
WHERE login = ?
AND baja = 0
});

$sth->execute($login);

# =========================================================
# ESCAPAR
# =========================================================

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

<title>Cuenta marcada para baja</title>

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

Cuenta marcada para eliminación

</h2>

<p>

La cuenta:

<b>$login_safe</b>

ha sido marcada correctamente.

</p>

<p>

El sistema eliminará automáticamente:

</p>

<ul>

<li>Usuario Linux</li>

<li>Directorio HOME</li>

<li>Web personal</li>

<li>Datos de la base de datos</li>

</ul>

<br>

<a href="/">

Volver al inicio

</a>

</div>

</body>

</html>

};

# =========================================================
# FIN
# =========================================================

$sth->finish();

$dbh->disconnect();
