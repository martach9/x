#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard);

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

my $post =
    $cgi->param('post') || '';

$login =~ s/^\s+|\s+$//g;
$post  =~ s/^\s+|\s+$//g;

# =========================================================
# VALIDAR
# =========================================================

unless (
    $login =~ /^[a-zA-Z0-9._-]+$/
    &&
    $post =~ /^post_\d+\.txt$/
) {

    print qq{

    <h2>Parámetros inválidos</h2>

    };

    exit;
}

# =========================================================
# RUTA
# =========================================================

my $ruta =
    "/home/$login/blog/posts/$post";

unless (-f $ruta) {

    print qq{

    <h2>Post no encontrado</h2>

    };

    exit;
}

# =========================================================
# BORRAR
# =========================================================

unlink($ruta)
    or die "No se pudo borrar el post";

# =========================================================
# RESPUESTA
# =========================================================

print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Post eliminado</title>

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

.btn{
    display:inline-block;
    margin-top:20px;
    background:#1ab188;
    color:white;
    text-decoration:none;
    padding:12px 20px;
    border-radius:5px;
}

</style>

</head>

<body>

<div class="card">

<h2 class="ok">

Post eliminado correctamente

</h2>

<a
class="btn"
href="/cgi-bin/verBlog.pl?login=$login">

Volver al blog

</a>

</div>

</body>

</html>

};
