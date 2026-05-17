#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use CGI::Carp qw(fatalsToBrowser);

require "/var/www/cgi-bin/conexion.pl";

my $cgi = CGI->new;

print $cgi->header(
    -type    => 'text/html',
    -charset => 'UTF-8'
);

# =========================================================
# TOKEN
# =========================================================

my $token = $cgi->param('token') || '';
$token =~ s/^\s+|\s+$//g;

unless ($token =~ /^[a-f0-9]{64}$/) {

    print "<h2>Token inválido</h2>";
    exit;
}

# =========================================================
# DB
# =========================================================

my $dbh = conexion::conectar();

my $sth = $dbh->prepare(q{
    SELECT login, activo
    FROM usuarios
    WHERE token = ?
});

$sth->execute($token);

my $u = $sth->fetchrow_hashref();

unless ($u) {

    print "<h2>Token no válido</h2>";
    exit;
}

if ($u->{activo}) {

    print "<h2>Cuenta ya activada</h2>";
    exit;
}

$dbh->disconnect();

# =========================================================
# FORMULARIO PASSWORD
# =========================================================

print qq{
<!DOCTYPE html>
<html lang="es">

<head>

<meta charset="UTF-8">

<title>Activar cuenta</title>

<style>

body{
    background:#13232f;
    color:white;
    font-family:Arial;
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
    padding:10px;
    margin-top:10px;
    box-sizing:border-box;
}

button{
    margin-top:20px;
    padding:10px 20px;
    cursor:pointer;
}

</style>

</head>

<body>

<div class="card">

<h2>Activación de cuenta</h2>

<p>
Introduce una contraseña para finalizar la activación.
</p>

<form method="post"
      action="/cgi-bin/agregarsistema.pl">

<input type="hidden"
       name="token"
       value="$token">

<label>Password</label>

<input type="password"
       name="password"
       required>

<label>Repetir password</label>

<input type="password"
       name="password2"
       required>

<button type="submit">
Finalizar activación
</button>

</form>

</div>

</body>
</html>
};
