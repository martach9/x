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
# BUSCAR USUARIO
# =========================================================

my $sth = $dbh->prepare(q{

SELECT
    login,
    nombre,
    email,
    direccion,
    tipo
FROM usuarios
WHERE login = ?

});

$sth->execute($login);

my $user =
    $sth->fetchrow_hashref();

# =========================================================
# NO EXISTE
# =========================================================

unless ($user) {

    print qq{

    <h2>Error</h2>

    <p>
    Usuario no encontrado.
    </p>

    };

    exit;
}

# =========================================================
# ESCAPAR
# =========================================================

my $login_safe =
    escapeHTML($user->{login});

my $nombre_safe =
    escapeHTML($user->{nombre});

my $email_safe =
    escapeHTML($user->{email});

my $direccion_safe =
    escapeHTML($user->{direccion});

my $tipo_safe =
    escapeHTML($user->{tipo});

# =========================================================
# HTML
# =========================================================

print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Datos personales</title>

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

h1{
    color:#1ab188;
}

.info{
    background:#1c2b36;
    padding:20px;
    border-radius:8px;
    margin-top:20px;
    margin-bottom:20px;
}

button{
    background:#1ab188;
    border:none;
    color:white;
    padding:12px 20px;
    border-radius:5px;
    cursor:pointer;
    width:100%;
    margin-bottom:15px;
    font-size:1em;
}

.baja{
    background:#922b21;
}

.volver{
    background:#34495e;
}

</style>

</head>

<body>

<div class="card">

<h1>

Datos personales

</h1>

<div class="info">

<p>

<b>Usuario:</b>

$login_safe

</p>

<p>

<b>Nombre:</b>

$nombre_safe

</p>

<p>

<b>Email:</b>

$email_safe

</p>

<p>

<b>Dirección:</b>

$direccion_safe

</p>

<p>

<b>Tipo:</b>

$tipo_safe

</p>

</div>

<!-- =============================================== -->
<!-- CAMBIAR NOMBRE -->
<!-- =============================================== -->

<form
action="/cgi-bin/cambiarNombre.pl"
method="GET">

<input
type="hidden"
name="login"
value="$login_safe">

<button type="submit">

Cambiar nombre

</button>

</form>

<!-- =============================================== -->
<!-- CAMBIAR DIRECCION -->
<!-- =============================================== -->

<form
action="/cgi-bin/cambiarDireccion.pl"
method="GET">

<input
type="hidden"
name="login"
value="$login_safe">

<button type="submit">

Cambiar dirección

</button>

</form>

<!-- =============================================== -->
<!-- CAMBIAR PASSWORD -->
<!-- =============================================== -->

<form
action="/cgi-bin/cambiarPassword.pl"
method="GET">

<input
type="hidden"
name="login"
value="$login_safe">

<button type="submit">

Cambiar contraseña

</button>

</form>

<!-- =============================================== -->
<!-- BAJA -->
<!-- =============================================== -->

<form
action="/cgi-bin/baja.pl"
method="GET">

<button
type="submit"
class="baja">

Darse de baja

</button>

</form>

<!-- =============================================== -->
<!-- VOLVER -->
<!-- =============================================== -->

<form
action="/~$login_safe"
method="GET">

<button
type="submit"
class="volver">

Volver

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
