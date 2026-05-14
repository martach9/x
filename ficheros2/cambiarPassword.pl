#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use CGI::Carp qw(fatalsToBrowser);

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

my $login =
    $cgi->param('login') || '';

$login =~ s/^\s+|\s+$//g;

my $login_safe =
    escapeHTML($login);

my $email =
    $cgi->param('email') || '';

$email =~ s/^\s+|\s+$//g;

# =========================================================
# MODO
# =========================================================

my $modo_recuperacion = 0;

unless ($login) {

    $modo_recuperacion = 1;
}

# =========================================================
# SI ENVIARON EMAIL
# =========================================================

if ($email) {

    # =====================================================
    # DB
    # =====================================================

    my $dbh = conexion::conectar();

    my $login_real = '';

    # =====================================================
    # CAMBIO NORMAL
    # =====================================================

    if (!$modo_recuperacion) {

        my $sth = $dbh->prepare(q{

        SELECT email
        FROM usuarios
        WHERE login = ?

        });

        $sth->execute($login);

        my ($email_bd) =
            $sth->fetchrow_array();

        unless (

            defined $email_bd
            &&
            $email eq $email_bd

        ) {

            print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Error</title>

</head>

<body>

<h2>

El correo no coincide
con el usuario.

</h2>

</body>

</html>

            };

            $sth->finish();
            $dbh->disconnect();

            exit;
        }

        $login_real = $login;

        $sth->finish();
    }

    # =====================================================
    # RECUPERAR PASSWORD
    # =====================================================

    else {

        my $sth = $dbh->prepare(q{

        SELECT login
        FROM usuarios
        WHERE login = ?
        AND email = ?

        });

        $sth->execute(
            $login,
            $email
        );

        ($login_real) =
            $sth->fetchrow_array();

        # =================================================
        # SI NO EXISTE
        # =================================================

        unless ($login_real) {

            print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Error</title>

</head>

<body>

<h2>

Usuario o correo incorrectos.

</h2>

</body>

</html>

            };

            $sth->finish();
            $dbh->disconnect();

            exit;
        }

        $sth->finish();
    }

    # =====================================================
    # TOKEN RESET
    # =====================================================

    my $token =
        sha256_hex(
            rand() .
            time() .
            $email .
            $login_real
        );

    # =====================================================
    # GUARDAR TOKEN
    # =====================================================

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
        $login_real
    );

    # =====================================================
    # LINK
    # =====================================================

    my $link =
"https://192.168.56.107/cgi-bin/resetPassword.pl?token=$token";

    # =====================================================
    # EMAIL
    # =====================================================

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

Hola $login_real

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

        print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Error Email</title>

</head>

<body>

<h2>

No se pudo enviar el correo.

</h2>

</body>

</html>

        };

        $dbh->disconnect();

        exit;
    }

    # =====================================================
    # RESPUESTA
    # =====================================================

    print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Correo enviado</title>

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

</style>

</head>

<body>

<div class="card">

<h2 class="ok">

Correo enviado correctamente

</h2>

<p>

Revise su bandeja de entrada.

</p>

</div>

</body>

</html>

    };

    $up->finish();
    $dbh->disconnect();

    exit;
}

# =========================================================
# FORMULARIO
# =========================================================

my $titulo =
    $modo_recuperacion
    ? 'Recuperar contraseña'
    : 'Cambiar contraseña';

my $texto =
    $modo_recuperacion
    ? 'Introduzca usuario y correo asociados a su cuenta.'
    : 'Por seguridad debe introducir el correo asociado a su cuenta.';

# =========================================================
# INPUT LOGIN
# =========================================================

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
else {

    $input_login = qq{

<input
type="hidden"
name="login"
value="$login_safe">

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
    font-size:1em;
    box-sizing:border-box;
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

.info{
    background:#1c2b36;
    padding:15px;
    border-radius:8px;
    margin-bottom:20px;
}

</style>

</head>

<body>

<div class="card">

<h2>

$titulo

</h2>

<div class="info">

<p>

$texto

</p>

</div>

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
