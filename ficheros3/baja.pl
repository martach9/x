#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use CGI::Carp qw(fatalsToBrowser);
use Authen::PAM qw(:constants);
use Fcntl qw(:flock);

require "/var/www/cgi-bin/conexion.pl";

my $cgi = CGI->new;

print $cgi->header(
    -type    => 'text/html',
    -charset => 'UTF-8'
);

my $email    = $cgi->param('email')    || '';
my $password = $cgi->param('password') || '';

unless ($email && $password) {
    print qq{
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Baja de usuario</title>
<style>
body{background:#13232f;color:white;font-family:Arial;padding:40px;}
.card{background:#24333e;padding:30px;border-radius:10px;max-width:500px;margin:auto;}
input{width:100%;padding:12px;margin-bottom:20px;border:none;border-radius:5px;}
button{background:#c0392b;border:none;color:white;padding:12px;border-radius:5px;width:100%;}
</style>
</head>
<body>
<div class="card">
<h2>Darse de baja</h2>
<form action="/cgi-bin/baja.pl" method="POST">
<input type="email" name="email" placeholder="Correo electrónico" required>
<input type="password" name="password" placeholder="Contraseña" required>
<button type="submit">Confirmar baja</button>
</form>
</div>
</body>
</html>
};
    exit;
}

$email =~ s/^\s+|\s+$//g;

unless ($email =~ /^[^\s\@]+@[^\s\@]+\.[^\s\@]+$/) {
    print "<h2>Error</h2><p>Email inválido.</p>";
    exit;
}

my $dbh = conexion::conectar();

my $sth = $dbh->prepare(q{
    SELECT login, activo, baja_pendiente
    FROM usuarios
    WHERE email = ?
});

$sth->execute($email);
my $user = $sth->fetchrow_hashref();

unless ($user) {
    print "<h2>Error</h2><p>El correo no existe.</p>";
    exit;
}

unless ($user->{activo}) {
    print "<h2>Error</h2><p>La cuenta no está activa.</p>";
    exit;
}

if ($user->{baja_pendiente}) {
    print "<h2>Baja ya solicitada</h2>";
    print "<p>La cuenta ya está pendiente de eliminación.</p>";
    exit;
}

my $login = $user->{login};

unless ($login =~ /^[a-z_][a-z0-9_-]{2,31}$/) {
    print "<h2>Error</h2><p>Login inválido.</p>";
    exit;
}

my $pamh = Authen::PAM->new(
    "ecosalmantica",
    $login,
    sub {
        my @response;

        while (@_) {
            my $code = shift;
            my $msg  = shift;

            if ($code == PAM_PROMPT_ECHO_OFF) {
                push @response, $password, 0;
            } else {
                push @response, "", 0;
            }
        }

        return (PAM_SUCCESS, @response);
    }
);

unless (defined $pamh) {
    print "<h2>Error PAM</h2><p>No se pudo inicializar PAM.</p>";
    exit;
}

my $retval = $pamh->pam_authenticate();

if ($retval != PAM_SUCCESS) {
    my $err = $pamh->pam_strerror($retval);
    $pamh->pam_end($retval);

    print "<h2>Error PAM</h2>";
    print "<p>" . escapeHTML($err) . "</p>";
    exit;
}

$pamh->pam_end(PAM_SUCCESS);
undef $pamh;
undef $password;

my @chars = ('a'..'z', 'A'..'Z', 0..9);
my $token = join('', map { $chars[int(rand(@chars))] } 1..40);

my $dir_bajas = "/var/ecosalmantica/bajas";

unless (-d $dir_bajas) {
    print "<h2>Error interno</h2>";
    print "<p>No existe el directorio de bajas.</p>";
    exit;
}

my $req = "$dir_bajas/$login.req";

if (-e $req) {
    print "<h2>Baja ya solicitada</h2>";
    print "<p>Ya existe una solicitud de baja pendiente para esta cuenta.</p>";
    exit;
}

my $fh;

unless (open $fh, '>', $req) {
    print "<h2>Error interno</h2>";
    print "<p>No se pudo crear la solicitud de baja.</p>";
    exit;
}

unless (flock($fh, LOCK_EX)) {
    print "<h2>Error interno</h2>";
    print "<p>No se pudo bloquear la solicitud de baja.</p>";
    close $fh;
    exit;
}

print $fh "login=$login\n";
print $fh "token=$token\n";
print $fh "fecha=" . time() . "\n";

close $fh;

chmod 0600, $req;

my $upd = $dbh->prepare(q{
    UPDATE usuarios
    SET token_baja = ?,
        baja_pendiente = 1
    WHERE login = ?
});

$upd->execute($token, $login);

$upd->finish();
$sth->finish();
$dbh->disconnect();

my $login_safe = escapeHTML($login);
my $email_safe = escapeHTML($email);

print qq{
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Baja solicitada</title>
<style>
body{background:#13232f;color:white;font-family:Arial;padding:40px;}
.card{background:#24333e;padding:30px;border-radius:10px;max-width:600px;margin:auto;}
.ok{color:#1ab188;}
</style>
</head>
<body>
<div class="card">

<h2 class="ok">Baja solicitada correctamente</h2>

<p>La cuenta <b>$login_safe</b> ha sido marcada para baja.</p>
<p>Correo: <b>$email_safe</b></p>

<p>El sistema eliminará automáticamente el usuario, su HOME, cuotas y datos asociados.</p>
<a href="/index.html"
   style="
      display:block;
      margin-top:30px;
      padding:15px;
      background:#1ab188;
      color:white;
      text-decoration:none;
      text-align:center;
      font-size:1.1em;
      font-weight:bold;
      border-radius:4px;
   ">
   Volver al login
</a>

</div>
</body>
</html>
};
