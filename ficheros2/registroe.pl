#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use Digest::SHA qw(sha256_hex);

use Email::Sender::Simple qw(sendmail);
use Email::Simple;
use Email::Simple::Creator;

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

my $login     = $cgi->param('login')     || '';
my $nombre    = $cgi->param('nombre')    || '';
my $email     = $cgi->param('email')     || '';
my $direccion = $cgi->param('direccion') || '';
my $password  = $cgi->param('password')  || '';

# =========================================================
# LIMPIEZA
# =========================================================

$login     =~ s/^\s+|\s+$//g;
$nombre    =~ s/^\s+|\s+$//g;
$email     =~ s/^\s+|\s+$//g;
$direccion =~ s/^\s+|\s+$//g;

# =========================================================
# VALIDACIONES
# =========================================================

my @errores;

unless (
    $login =~ /^[a-z_][a-z0-9_-]{2,31}$/
) {

    push @errores,
        "Login invalido.";
}

unless (
    length($nombre) >= 3
) {

    push @errores,
        "Nombre demasiado corto.";
}

unless (
    $email =~ /^[A-Za-z0-9._%+-]+\@(usal\.es|hotmail\.com|gmail\.com)$/i
) {

    push @errores,
        "Solo se permiten correos \@usal.es, \@hotmail.com y \@gmail.com";
}

unless (
    length($password) >= 8
) {

    push @errores,
        "La contraseña debe tener al menos 8 caracteres.";
}

unless (
    length($direccion) >= 5
) {

    push @errores,
        "Direccion invalida.";
}

my %usuarios_reservados = map {
    $_ => 1
} qw(
    root
    daemon
    bin
    sys
    sync
    games
    man
    lp
    mail
    nobody
    www-data
    mysql
);

if ($usuarios_reservados{$login}) {

    push @errores,
        "Nombre de usuario reservado.";
}

# =========================================================
# MOSTRAR ERRORES
# =========================================================

if (@errores) {

    print qq{
    <h2>Error en el registro</h2>
    <ul>
    };

    foreach my $e (@errores) {

        my $safe = escapeHTML($e);

        print qq{
        <li>$safe</li>
        };
    }

    print qq{
    </ul>
    };

    exit;
}

# =========================================================
# ESCAPAR HTML
# =========================================================

my $login_safe  = escapeHTML($login);

my $nombre_safe = escapeHTML($nombre);

# =========================================================
# TIPO USUARIO
# =========================================================

my $tipo_usuario = 'ciudadano';

if (
    $email =~ /\@usal\.es$/i
) {

    $tipo_usuario = 'operario';
}

# =========================================================
# HASH LINUX / WEB
# =========================================================

my $salt_web =
    substr(
        sha256_hex(rand() . time() . $$),
        0,
        16
    );

my $hash_web =
    crypt(
        $password,
        '$6$' . $salt_web . '$'
    );

# =========================================================
# TOKEN ACTIVACION
# =========================================================

my $token =
    sha256_hex(
        rand() . time() . $email
    );

# =========================================================
# DB
# =========================================================

my $dbh = conexion::conectar();

# =========================================================
# COMPROBAR EXISTENCIA
# =========================================================

my $check = $dbh->prepare(

    q{
        SELECT login
        FROM usuarios
        WHERE login = ?
        OR email = ?
    }

);

$check->execute(
    $login,
    $email
);

if ($check->fetchrow_array()) {

    print qq{
    <h2>Error</h2>
    <p>El usuario o correo ya existen.</p>
    };

    exit;
}

# =========================================================
# INSERT DB
# =========================================================

my $sql = q{

INSERT INTO usuarios
(
    login,
    nombre,
    email,
    password,
    salt,
    password_linux,
    direccion,
    tipo,
    activo,
    token,
    fecha_token
)
VALUES
(
    ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, NOW()
)

};

my $sth = $dbh->prepare($sql);

eval {

    $sth->execute(

        $login,
        $nombre,
        $email,
        $hash_web,
        $salt_web,
	$hash_web,
        $direccion,
        $tipo_usuario,
        $token,
    );
};

if ($@) {

    print qq{
    <h2>Error DB</h2>
    <pre>$DBI::errstr</pre>
    };

    exit;
}

# =========================================================
# ENVIAR EMAIL
# =========================================================

my $link =
"https://192.168.56.107/cgi-bin/activacion.pl?token=$token";

my $email_obj = Email::Simple->create(

    header => [

        To => $email,

        From => 'noreply@ecosalmantica.es',

        Subject => 'Activacion de cuenta'

    ],

    body => qq{

Hola $nombre

Pulse el siguiente enlace para activar su cuenta:

$link

    }

);

eval {

    sendmail($email_obj);

};

if ($@) {

    print qq{
    <h2>Error Email</h2>
    <p>No se pudo enviar el correo.</p>
    };

    exit;
}

# =========================================================
# RESPUESTA
# =========================================================

print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Registro pendiente</title>

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

.success{
    color:#1ab188;
}

a{
    color:#4eb5f1;
}

</style>

</head>

<body>

<div class="card">

<h2 class="success">

Registro pendiente de activacion

</h2>

<p>

Se ha enviado un correo de activacion a:

</p>

<p>

<b>$email</b>

</p>

<p>

Revise su bandeja de entrada para continuar.

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
