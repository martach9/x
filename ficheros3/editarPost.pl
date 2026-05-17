#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);

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

my $titulo =
    $cgi->param('titulo') || '';

my $texto =
    $cgi->param('texto') || '';

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
    "/home/$login/public_html/blog/posts/$post";

unless (-f $ruta) {

    print qq{

    <h2>Post no encontrado</h2>

    };

    exit;
}

# =========================================================
# GUARDAR CAMBIOS
# =========================================================

if ($titulo && $texto) {

    open(
        my $fh,
        '<',
        $ruta
    ) or die "No se pudo abrir";

    my @lineas = <$fh>;

    close($fh);

    my $autor =
        $lineas[0] || '';

    my $fecha =
        $lineas[1] || '';

    chomp($autor);
    chomp($fecha);

    open(
        my $out,
        '>',
        $ruta
    ) or die "No se pudo escribir";

    print $out "$autor\n";
    print $out "$fecha\n";
    print $out "$titulo\n";
    print $out "$texto";

    close($out);

    print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Post actualizado</title>

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

Post actualizado correctamente

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

    exit;
}

# =========================================================
# LEER POST
# =========================================================

open(
    my $fh,
    '<',
    $ruta
) or die "No se pudo abrir";

my $contenido = do {

    local $/;
    <$fh>
};

close($fh);

my (
    $autor,
    $fecha,
    $titulo_actual,
    $texto_actual
) = split(/\n/, $contenido, 4);

$titulo_actual =
    escapeHTML($titulo_actual || '');

$texto_actual =
    escapeHTML($texto_actual || '');

# =========================================================
# FORMULARIO
# =========================================================

print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Editar post</title>

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
    max-width:800px;
    margin:auto;
}

input,
textarea{
    width:100%;
    padding:12px;
    margin-bottom:20px;
    border:none;
    border-radius:5px;
    font-size:1em;
    box-sizing:border-box;
}

textarea{
    height:250px;
    resize:vertical;
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

Editar post

</h2>

<form
action="/cgi-bin/editarPost.pl"
method="POST">

<input
type="hidden"
name="login"
value="$login">

<input
type="hidden"
name="post"
value="$post">

<input
type="text"
name="titulo"
value="$titulo_actual"
required>

<textarea
name="texto"
required>$texto_actual</textarea>

<button type="submit">

Guardar cambios

</button>

</form>

</div>

</body>

</html>

};
