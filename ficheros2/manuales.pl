#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);

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

    print qq{

    <h2>Usuario inválido</h2>

    };

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

    print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Acceso denegado</title>

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

</style>

</head>

<body>

<div class="card">

<h2 class="error">

Acceso denegado

</h2>

<p>

Solo los operarios pueden acceder
a los manuales SmartCity.

</p>

</div>

</body>

</html>

    };

    $dbh->disconnect();

    exit;
}

# =========================================================
# DIRECTORIO
# =========================================================

my $dir =
    "/manuales_smartcity";

# =========================================================
# LEER ARCHIVOS
# =========================================================

opendir(
    my $dh,
    $dir
) or die "No se pudo abrir directorio";

my @archivos =
    grep {

        -f "$dir/$_"

    } readdir($dh);

closedir($dh);

# =========================================================
# ORDENAR
# =========================================================

@archivos =
    sort @archivos;

# =========================================================
# HTML ARCHIVOS
# =========================================================

my $lista = '';

foreach my $archivo (@archivos) {

    my $safe =
        escapeHTML($archivo);

    $lista .= qq{

    <div class="archivo">

        <div class="nombre">

            <i class="fas fa-file-alt"></i>

            $safe

        </div>

        <div class="acciones">

            <a
            class="btn"
            target="_blank"
            href="/manuales/$safe">

            Descargar

            </a>

            <a
            class="btn borrar"
            href="/cgi-bin/borrarManual.pl?login=$login&archivo=$safe">

            Borrar

            </a>

        </div>

    </div>

    };
}

# =========================================================
# SIN ARCHIVOS
# =========================================================

unless ($lista) {

    $lista = qq{

    <p>

    No hay manuales subidos.

    </p>

    };
}

# =========================================================
# HTML
# =========================================================

print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Manuales SmartCity</title>

<link rel="stylesheet"
href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">

<style>

body{
    background:#13232f;
    color:white;
    font-family:Arial,sans-serif;
    padding:40px;
}

.container{
    max-width:1000px;
    margin:auto;
}

.card{
    background:#24333e;
    padding:30px;
    border-radius:10px;
}

h1{
    margin-top:0;
    color:#1ab188;
}

.archivo{
    background:#1c2b36;
    padding:20px;
    border-radius:8px;
    margin-top:20px;

    display:flex;
    justify-content:space-between;
    align-items:center;
}

.nombre{
    font-size:1.1em;
}

.acciones{
    display:flex;
    gap:10px;
}

.btn{
    background:#1ab188;
    color:white;
    text-decoration:none;
    padding:10px 16px;
    border-radius:5px;
}

.btn:hover{
    background:#17a07b;
}

.borrar{
    background:#e74c3c;
}

.borrar:hover{
    background:#c0392b;
}

.upload{
    margin-top:30px;
    background:#1c2b36;
    padding:20px;
    border-radius:8px;
}

input[type=file]{
    margin-top:15px;
    margin-bottom:20px;
    color:white;
}

button{
    background:#1ab188;
    border:none;
    color:white;
    padding:12px 20px;
    border-radius:5px;
    cursor:pointer;
}

button:hover{
    background:#17a07b;
}

</style>

</head>

<body>

<div class="container">

<div class="card">

<h1>

<i class="fas fa-hard-hat"></i>

Manuales SmartCity

</h1>

<p>

Panel compartido de documentación técnica municipal.

</p>

$lista

<div class="upload">

<h2>

Subir manual

</h2>

<form
action="/cgi-bin/subirManual.pl"
method="POST"
enctype="multipart/form-data">

<input
type="hidden"
name="login"
value="$login">

<input
type="file"
name="manual"
required>

<br>

<button type="submit">

Subir archivo

</button>

</form>

</div>

</div>

</div>

</body>

</html>

};

# =========================================================
# FIN
# =========================================================

$dbh->disconnect();
