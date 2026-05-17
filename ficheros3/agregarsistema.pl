#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use CGI::Carp qw(fatalsToBrowser);
use Digest::SHA qw(sha256_hex);
use Fcntl qw(:flock);

require "/var/www/cgi-bin/conexion.pl";

my $cgi = CGI->new;

print $cgi->header(
    -type    => 'text/html',
    -charset => 'UTF-8'
);

my $token     = $cgi->param('token')     || '';
my $password  = $cgi->param('password')  || '';
my $password2 = $cgi->param('password2') || '';

$token =~ s/^\s+|\s+$//g;

unless ($token =~ /^[a-f0-9]{64}$/) {
    print "<h2>Token inválido</h2>";
    exit;
}

unless ($password eq $password2) {
    print "<h2>Las contraseñas no coinciden</h2>";
    exit;
}

unless ($password =~ /(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}/) {
    print "<h2>Contraseña débil</h2>";
    print "<p>Debe tener mínimo 8 caracteres, mayúscula, minúscula y número.</p>";
    exit;
}

my $dbh = conexion::conectar();

my $sth = $dbh->prepare(q{
    SELECT login, nombre, email, tipo, activo, procesado
    FROM usuarios
    WHERE token = ?
});

$sth->execute($token);

my $u = $sth->fetchrow_hashref();

unless ($u) {
    print "<h2>Token no válido</h2>";
    exit;
}

if ($u->{activo} || $u->{procesado}) {
    print "<h2>Cuenta ya activada</h2>";
    exit;
}

my $login  = $u->{login};
my $nombre = $u->{nombre};
my $email = $u->{email};
my $tipo = 'ciudadano';

if ($email =~ /\@usal\.es$/i) {
    $tipo = 'operario';
}

if (getpwnam($login)) {
    print "<h2>El usuario ya existe en el sistema</h2>";
    exit;
}

sub hash_shadow {
    my ($pass) = @_;

    my @chars = ('.', '/', 0..9, 'A'..'Z', 'a'..'z');
    my $salt = '';

    $salt .= $chars[int(rand(@chars))] for 1..16;

    return crypt($pass, "\$6\$$salt\$");
}

my $shadow_hash = hash_shadow($password);

undef $password;
undef $password2;

my $dir_pendientes = "/var/ecosalmantica/pendientes";

unless (-d $dir_pendientes) {
    print "<h2>Error interno</h2>";
    print "<p>No existe el directorio de pendientes.</p>";
    exit;
}

my $req = "$dir_pendientes/$login.req";

if (-e $req) {
    print "<h2>La activación ya está pendiente</h2>";
    exit;
}

open my $fh, '>', $req
    or die "No puedo crear solicitud pendiente";

flock($fh, LOCK_EX);

print $fh "login=$login\n";
print $fh "nombre=$nombre\n";
print $fh "email=$email\n";
print $fh "tipo=$tipo\n";
print $fh "hash=$shadow_hash\n";

close $fh;

chmod 0600, $req;

print qq{
<!DOCTYPE html>
<html lang="es">

<head>

<meta charset="UTF-8">

<title>Activación solicitada</title>

<style>

body{
    margin:0;
    font-family:'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;

    background:
        linear-gradient(
            135deg,
            rgba(13,31,20,0.93) 0%,
            rgba(0,168,88,0.72) 100%
        ),
        url('https://images.unsplash.com/photo-1480714378408-67cf0d13bc1b?w=1600&q=80')
        center/cover no-repeat fixed;

    display:flex;
    justify-content:center;
    align-items:center;
    min-height:100vh;
    color:white;
}

.card{
    background:#1c2b36;
    padding:40px;
    border-radius:10px;
    box-shadow:0 10px 25px rgba(0,0,0,0.5);
    width:100%;
    max-width:520px;
    text-align:center;
}

.ok{
    color:#1ab188;
    font-size:2em;
    margin-bottom:20px;
}

p{
    color:#d8e6e2;
    font-size:1.05em;
    line-height:1.7;
}

.login-btn{
    display:block;
    margin-top:30px;
    padding:15px;
    background:#1ab188;
    color:white;
    text-decoration:none;
    font-size:1.1em;
    font-weight:bold;
    border-radius:4px;
    transition:0.3s;
}

.login-btn:hover{
    background:#17a07b;
}

.usuario{
    color:#1ab188;
    font-weight:bold;
}

</style>

</head>

<body>

<div class="card">

<h2 class="ok">
Activación solicitada
</h2>

<p>
La cuenta
<span class="usuario">
@{[ escapeHTML($login) ]}
</span>
está lista para ser creada en el sistema.
</p>

<p>
La solicitud se ha añadido correctamente y será procesada automáticamente.
</p>

<a href="/index.html" class="login-btn">
Volver al login
</a>

</div>

</body>

</html>
};
