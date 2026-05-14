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
# RUTA BLOG
# =========================================================

my $blog_dir =
    "/home/$login/blog/posts";

# =========================================================
# EXISTE BLOG
# =========================================================

unless (-d $blog_dir) {

    print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Blog no encontrado</title>

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
    max-width:900px;
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

El blog no existe

</h2>

</div>

</body>

</html>

    };

    exit;
}

# =========================================================
# LEER POSTS
# =========================================================

opendir(
    my $dh,
    $blog_dir
) or die "No se pudo abrir blog";

my @posts =
    grep {

        /^post_\d+\.txt$/

    } readdir($dh);

closedir($dh);

# =========================================================
# ORDENAR POSTS
# =========================================================

@posts =
    sort { $b cmp $a } @posts;

# =========================================================
# HTML POSTS
# =========================================================

my $posts_html = '';

foreach my $file (@posts) {

    my $ruta =
        "$blog_dir/$file";

    open(
        my $fh,
        '<',
        $ruta
    ) or next;

    my $contenido = do {

        local $/;
        <$fh>
    };

    close($fh);

    my (
        $autor,
        $fecha,
        $titulo,
        $texto
    ) = split(/\n/, $contenido, 4);

    $autor  = escapeHTML($autor  || '');
    $fecha  = escapeHTML($fecha  || '');
    $titulo = escapeHTML($titulo || '');
    $texto  = escapeHTML($texto  || '');

    $texto =~ s/\n/<br>/g;

    $posts_html .= qq{

    <div class="post">

        <h3>

        $titulo

        </h3>

        <div class="meta">

            Publicado por
            <b>$autor</b>

            el

            $fecha

        </div>

        <div class="texto">

            $texto

        </div>

        <div class="acciones">

            <a
            class="btn-small"
            href="/cgi-bin/editarPost.pl?login=$login&post=$file">

            Editar

            </a>

            <a
            class="btn-small danger"
            href="/cgi-bin/borrarPost.pl?login=$login&post=$file"
            onclick="return confirm('¿Eliminar este post?');">

            Borrar

            </a>

        </div>

    </div>

    };
}

# =========================================================
# SIN POSTS
# =========================================================

unless ($posts_html) {

    $posts_html = qq{

    <p>

    Todavía no hay publicaciones.

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

<title>Blog de $login</title>

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
}

.post{
    background:#1c2b36;
    padding:20px;
    border-radius:8px;
    margin-top:20px;
}

.meta{
    color:#a0b3b0;
    margin-bottom:15px;
    font-size:0.9em;
}

.texto{
    line-height:1.6em;
}

.btn{
    display:inline-block;
    margin-top:20px;
    margin-right:10px;
    background:#1ab188;
    color:white;
    text-decoration:none;
    padding:12px 20px;
    border-radius:5px;
}

.btn:hover{
    background:#17a07b;
}

.acciones{
    margin-top:20px;
}

.btn-small{
    display:inline-block;
    background:#3498db;
    color:white;
    text-decoration:none;
    padding:8px 14px;
    border-radius:5px;
    margin-right:10px;
}

.btn-small:hover{
    background:#2980b9;
}

.danger{
    background:#e74c3c;
}

.danger:hover{
    background:#c0392b;
}

</style>

</head>

<body>

<div class="container">

<div class="card">

<h1>

Blog de $login

</h1>

<a
class="btn"
href="/cgi-bin/nuevoPost.pl?login=$login">

Nuevo post

</a>

<a
class="btn"
href="/~$login">

Volver al perfil

</a>

$posts_html

</div>

</div>

</body>

</html>

};
