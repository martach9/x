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

# =========================
# CGI
# =========================

my $cgi = CGI->new;

print $cgi->header(
    -type    => 'text/html',
    -charset => 'UTF-8'
);

# =========================
# SESIÓN
# =========================

CGI::Session->name("ECOSESSION");

my $session = CGI::Session->new(
    undef,
    $cgi,
    { Directory => '/var/lib/ecosalmantica/sessions' }
);

my $autenticado  = $session->param('autenticado') || 0;
my $login_sesion = $session->param('usuario') || '';

# =========================
# PARAMETROS
# =========================

my $login = $cgi->param('login') || '';
my $email = $cgi->param('email') || '';

$login =~ s/^\s+|\s+$//g;
$email =~ s/^\s+|\s+$//g;

my $login_safe = escapeHTML($login);

# =========================
# MODO
# =========================

my $modo_recuperacion = 0;

if (!$login) {
    if ($autenticado) {
        $login = $login_sesion;
    } else {
        $modo_recuperacion = 1;
    }
}

# =========================
# DB
# =========================

my $dbh = conexion::conectar();

# =========================================================
# PROCESO FORMULARIO
# =========================================================

if ($email) {

    my $login_real = '';

    # =========================
    # RECUPERACIÓN
    # =========================

    if ($modo_recuperacion) {

        my $sth = $dbh->prepare(q{
            SELECT login
            FROM usuarios
            WHERE login = ? AND email = ?
        });

        $sth->execute($login, $email);
        ($login_real) = $sth->fetchrow_array();
        $sth->finish();

        if (!$login_real) {
            print_error("Usuario o correo incorrectos");
            exit;
        }
    }

    # =========================
    # CAMBIO NORMAL
    # =========================

    else {

        my $sth = $dbh->prepare(q{
            SELECT email
            FROM usuarios
            WHERE login = ?
        });

        $sth->execute($login);
        my ($email_bd) = $sth->fetchrow_array();
        $sth->finish();

        if (!$email_bd || $email ne $email_bd) {
            print_error("El correo no coincide con el usuario");
            exit;
        }

        $login_real = $login;
    }

    # =========================
    # TOKEN
    # =========================

    my $token = sha256_hex(rand() . time() . $email . $login_real);

    my $up = $dbh->prepare(q{
        UPDATE usuarios
        SET reset_token = ?,
            reset_expira = DATE_ADD(NOW(), INTERVAL 10 MINUTE)
        WHERE login = ?
    });

    $up->execute($token, $login_real);
    $up->finish();

    # =========================
    # EMAIL
    # =========================

    my $link = "https://192.168.56.107/cgi-bin/resetPassword.pl?token=$token";

    my $email_obj = Email::Simple->create(
        header => [
            To      => $email,
            From    => 'noreply@ecosalmantica.es',
            Subject => 'Cambio de contraseña'
        ],
        body => "Hola $login_real\n\nHas solicitado cambiar tu contraseña.\n\n$link\n\nExpira en 10 minutos."
    );

    eval { sendmail($email_obj); };

    if ($@) {
        print_error("No se pudo enviar el correo");
        exit;
    }

    # =========================
    # UI RESTAURADA (IMPORTANTE)
    # =========================

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

a{
    display:block;
    margin-top:20px;
    padding:12px;
    background:#8e44ad;
    color:white;
    text-decoration:none;
    text-align:center;
    border-radius:6px;
}
</style>

</head>

<body>

<div class="card">

<h2 class="ok">Correo enviado correctamente</h2>

<p>Revisa tu bandeja de entrada y sigue el enlace para cambiar la contraseña.</p>

<a href="/index.html">Volver al inicio</a>

</div>

</body>
</html>
    };

    $dbh->disconnect();
    exit;
}

# =========================================================
# FORMULARIO ORIGINAL RESTAURADO
# =========================================================

print qq{
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">

<title>Cambiar contraseña</title>

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
}

button{
    width:100%;
    padding:12px;
    background:#8e44ad;
    color:white;
    border:none;
    border-radius:5px;
    cursor:pointer;
}
</style>

</head>

<body>

<div class="card">

<h2>Cambiar contraseña</h2>

<form method="POST">
};

if (!$modo_recuperacion) {
    print qq{
        <input type="hidden" name="login" value="$login_safe">
    };
} else {
    print qq{
        <input type="text" name="login" placeholder="Usuario" required>
    };
}

print qq{
    <input type="email" name="email" placeholder="Correo electrónico" required>
    <button type="submit">Enviar enlace</button>
</form>

</div>

</body>
</html>
};

$dbh->disconnect();
exit;

# =========================
# ERROR HELPER
# =========================

sub print_error {
    my ($msg) = @_;

    print qq{
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Error</title>
</head>
<body style="background:#13232f;color:white;font-family:Arial;padding:40px;">

<h2>$msg</h2>

<a href="/index.html">Volver</a>

</body>
</html>
    };
}
