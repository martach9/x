#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use CGI::Carp qw(fatalsToBrowser);
use Fcntl qw(:flock);

require "/var/www/cgi-bin/conexion.pl";

my $cgi = CGI->new;

print $cgi->header(
    -type    => 'text/html',
    -charset => 'UTF-8'
);

my $token     = $cgi->param('token')     || '';
my $password1 = $cgi->param('password1') || '';
my $password2 = $cgi->param('password2') || '';

$token =~ s/^\s+|\s+$//g;

unless ($token =~ /^[a-f0-9]{64}$/) {
    print "<h2>Token inválido</h2>";
    exit;
}

my $dbh = conexion::conectar();

my $sth = $dbh->prepare(q{
    SELECT login, reset_expira
    FROM usuarios
    WHERE reset_token = ?
      AND reset_expira > NOW()
});

$sth->execute($token);
my $user = $sth->fetchrow_hashref();

unless ($user) {
    print "<h2>Error</h2><p>El enlace ha expirado o no es válido.</p>";
    $sth->finish();
    $dbh->disconnect();
    exit;
}

my $login = $user->{login};

unless ($login =~ /^[a-z_][a-z0-9_-]{2,31}$/) {
    print "<h2>Error</h2><p>Login inválido.</p>";
    exit;
}

unless ($password1 && $password2) {
    print qq{
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Nueva contraseña</title>
<style>
body{background:#13232f;color:white;font-family:Arial,sans-serif;padding:40px;}
.card{background:#24333e;padding:30px;border-radius:10px;max-width:600px;margin:auto;}
input{width:100%;padding:12px;margin-bottom:20px;border:none;border-radius:5px;font-size:1em;box-sizing:border-box;}
button{background:#8e44ad;border:none;color:white;padding:12px 20px;border-radius:5px;cursor:pointer;width:100%;}
</style>
</head>
<body>
<div class="card">
<h2>Nueva contraseña</h2>
<form action="/cgi-bin/resetPassword.pl" method="POST">
<input type="hidden" name="token" value="@{[escapeHTML($token)]}">
<input type="password" name="password1" placeholder="Nueva contraseña" required>
<input type="password" name="password2" placeholder="Repita la contraseña" required>
<button type="submit">Cambiar contraseña</button>
</form>
</div>
</body>
</html>
};
    $sth->finish();
    $dbh->disconnect();
    exit;
}

unless ($password1 eq $password2) {
    print "<h2>Error</h2><p>Las contraseñas no coinciden.</p>";
    exit;
}

unless ($password1 =~ /(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}/) {
    print "<h2>Error</h2><p>Debe tener mínimo 8 caracteres, mayúscula, minúscula, número y símbolo.</p>";
    exit;
}

sub hash_shadow {
    my ($pass) = @_;

    my @chars = ('.', '/', 0..9, 'A'..'Z', 'a'..'z');
    my $salt = '';

    $salt .= $chars[int(rand(@chars))] for 1..16;

    return crypt($pass, "\$6\$$salt\$");
}

my $shadow_hash = hash_shadow($password1);

undef $password1;
undef $password2;

my $dir_password = "/var/ecosalmantica/password";

unless (-d $dir_password) {
    print "<h2>Error interno</h2><p>No existe el directorio de cambios de contraseña.</p>";
    exit;
}

my $req = "$dir_password/$login.req";

my $fh;

unless (open $fh, '>', $req) {
    print "<h2>Error interno</h2><p>No se pudo crear la solicitud.</p>";
    exit;
}

unless (flock($fh, LOCK_EX)) {
    print "<h2>Error interno</h2><p>No se pudo bloquear la solicitud.</p>";
    close $fh;
    exit;
}

print $fh "login=$login\n";
print $fh "hash=$shadow_hash\n";
print $fh "fecha=" . time() . "\n";

close $fh;

chmod 0600, $req;

my $up = $dbh->prepare(q{
    UPDATE usuarios
    SET reset_token = NULL,
        reset_expira = NULL
    WHERE login = ?
});

$up->execute($login);

$up->finish();
$sth->finish();
$dbh->disconnect();

my $login_safe = escapeHTML($login);

print qq{
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Contraseña solicitada</title>
<style>
body{background:#13232f;color:white;font-family:Arial,sans-serif;padding:40px;}
.card{background:#24333e;padding:30px;border-radius:10px;max-width:600px;margin:auto;}
.ok{color:#1ab188;}
</style>
</head>
<body>
<div class="card">
<h2 class="ok">Cambio de contraseña solicitado</h2>
<p>La contraseña del usuario <b>$login_safe</b> será actualizada automáticamente.</p>
</div>
</body>
</html>
};
