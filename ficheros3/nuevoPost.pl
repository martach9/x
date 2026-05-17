#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use CGI::Carp qw(fatalsToBrowser);

use POSIX qw(strftime);

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

my $autor =
    $cgi->param('autor') || '';

my $mensaje =
    $cgi->param('mensaje') || '';

$login   =~ s/^\s+|\s+$//g;
$autor   =~ s/^\s+|\s+$//g;
$mensaje =~ s/^\s+|\s+$//g;

# =========================================================
# VALIDAR LOGIN
# =========================================================

unless (

    length($login)
    &&
    $login =~ /^[a-zA-Z0-9._-]+$/

) {

    print qq{

    <h2>Usuario inválido</h2>

    };

    exit;
}

# =========================================================
# SI NO HAY MENSAJE
# MOSTRAR FORMULARIO
# =========================================================

unless ($mensaje) {

    print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Nuevo Post</title>

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

textarea{
    width:100%;
    height:220px;
    padding:12px;
    border:none;
    border-radius:5px;
    resize:vertical;
    font-size:1em;
    box-sizing:border-box;
}

input{
    width:100%;
    padding:12px;
    margin-bottom:20px;
    border:none;
    border-radius:5px;
    font-size:1em;
    box-sizing:border-box;
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

Nuevo post para $login

</h2>

<form
action="/cgi-bin/nuevoPost.pl"
method="POST">

<input
type="hidden"
name="login"
value="$login">

<input
type="text"
name="autor"
placeholder="Tu nombre"
required>

<textarea
name="mensaje"
placeholder="Escribe tu mensaje..."
required></textarea>

<br><br>

<button type="submit">

Publicar

</button>

</form>

</div>

</body>

</html>

    };

    exit;
}

# =========================================================
# DIRECTORIO POSTS
# =========================================================

my $dir =
    "/home/$login/public_html/blog/posts";

unless (-d $dir) {

    print qq{

    <h2>Error</h2>

    <p>
    El blog no existe.
    </p>

    };

    exit;
}

# =========================================================
# NOMBRE FICHERO
# =========================================================

my $timestamp = time();

my $archivo =
    "$dir/post_$timestamp.txt";

# =========================================================
# FECHA
# =========================================================

my $fecha =
    strftime(
        "%Y-%m-%d %H:%M:%S",
        localtime
    );

# =========================================================
# GUARDAR POST
# =========================================================

open(
    my $fh,
    '>',
    $archivo
) or die "No se pudo crear post en $archivo: $!";

print $fh <<"EOF";
$autor
$fecha
Nuevo Post

$mensaje
EOF

close($fh);

chmod(
    0644,
    $archivo
);

# =========================================================
# RESPUESTA
# =========================================================

print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Post creado</title>

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

Post publicado correctamente

</h2>

<p>

<a href="/cgi-bin/verBlog.pl?login=$login">

Volver al blog

</a>

</p>

</div>

</body>

</html>

};
