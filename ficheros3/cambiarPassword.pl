#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use CGI::Carp qw(fatalsToBrowser);
use CGI::Session;

use Digest::SHA qw(sha256_hex);

use Email::Sender::Simple qw(sendmail);
use Email::Simple;
use Email::Simple::Creator;

require "/var/www/cgi-bin/conexion.pl";

# =========================================================
# CGI
# =========================================================

my $cgi = CGI->new;

# =========================================================
# SESION
# =========================================================

CGI::Session->name("ECOSESSION");

my $session = CGI::Session->new(
    undef,
    $cgi,
    { Directory => '/var/lib/ecosalmantica/sessions' }
);

my $autenticado =
    $session->param('autenticado') || 0;

my $login_sesion =
    $session->param('usuario') || '';

# =========================================================
# PARAMETROS
# =========================================================

my $login =
    $cgi->param('login') || '';

my $email =
    $cgi->param('email') || '';

$login =~ s/^\s+|\s+$//g;
$email =~ s/^\s+|\s+$//g;

# =========================================================
# MODO
# =========================================================

my $modo_recuperacion = 0;

if ($autenticado) {

    $login = $login_sesion;
}
else {

    $modo_recuperacion = 1;
}

# =========================================================
# FORMULARIO
# =========================================================

unless ($email) {

    my $titulo =
        $modo_recuperacion
        ? 'Recuperar contraseña'
        : 'Cambiar contraseña';

    my $texto =
        $modo_recuperacion
        ? 'Introduzca usuario y correo asociados a su cuenta.'
        : 'Introduzca el correo asociado a su cuenta.';

    my $input_login = '';

    if ($modo_recuperacion) {

        $input_login = qq{

<input
type="text"
name="login"
placeholder="Usuario"
required>

        };
    }

    print $cgi->header(
        -type    => 'text/html',
        -charset => 'UTF-8'
    );

    print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>$titulo</title>

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

input{
    width:100%;
    padding:12px;
    margin-bottom:20px;
    border:none;
    border-radius:5px;
}

button{
    background:#8e44ad;
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

$titulo

</h2>

<p>

$texto

</p>

<form
action="/cgi-bin/cambiarPassword.pl"
method="POST">

$input_login

<input
type="email"
name="email"
placeholder="Correo electrónico"
required>

<button type="submit">

Enviar enlace

</button>

</form>

</div>

</body>

</html>

    };

    exit;
}

# =========================================================
# VALIDAR LOGIN
# =========================================================

unless ($login =~ /^[a-z_][a-z0-9_-]{2,31}$/) {

    print $cgi->redirect('/');
    exit;
}

# =========================================================
# DB
# =========================================================

my $dbh = conexion::conectar();

# =========================================================
# COMPROBAR EMAIL
# =========================================================

my $sth = $dbh->prepare(q{

SELECT email
FROM usuarios
WHERE login = ?

});

$sth->execute($login);

my ($email_bd) =
    $sth->fetchrow_array();

$sth->finish();

unless (
    defined $email_bd
    &&
    $email eq $email_bd
) {

    print $cgi->header(
        -type    => 'text/html',
        -charset => 'UTF-8'
    );

    print qq{

<h2>

Error

</h2>

<p>

El correo no coincide con el usuario.

</p>

    };

    $dbh->disconnect();

    exit;
}

# =========================================================
# TOKEN
# =========================================================

my $token =
    sha256_hex(
        rand() .
        time() .
        $email .
        $login
    );

# =========================================================
# GUARDAR TOKEN
# =========================================================

my $up = $dbh->prepare(q{

UPDATE usuarios
SET
    reset_token = ?,
    reset_expira =
        DATE_ADD(
            NOW(),
            INTERVAL 10 MINUTE
        )
WHERE login = ?

});

$up->execute(
    $token,
    $login
);

$up->finish();

# =========================================================
# LINK
# =========================================================

my $link =
"https://192.168.56.107/cgi-bin/resetPassword.pl?token=$token";

# =========================================================
# EMAIL
# =========================================================

my $email_obj =
    Email::Simple->create(

    header => [

        To => $email,

        From =>
            'noreply@ecosalmantica.es',

        Subject =>
            'Cambio de contraseña'

    ],

    body => qq{

Hola $login

Ha solicitado cambiar su contraseña.

Pulse el siguiente enlace:

$link

El enlace expirará en 10 minutos.

    }

);

eval {

    sendmail($email_obj);

};

if ($@) {

    print $cgi->header(
        -type    => 'text/html',
        -charset => 'UTF-8'
    );

    print qq{

<h2>

Error enviando correo

</h2>

    };

    $dbh->disconnect();

    exit;
}

$dbh->disconnect();

# =========================================================
# REDIRECT
# =========================================================

print $cgi->redirect(
    '/cgi-bin/datosPersonales.pl?ok=password'
);

exit;
