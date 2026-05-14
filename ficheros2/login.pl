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

my $password =
    $cgi->param('password') || '';

# =========================================================
# LIMPIEZA
# =========================================================

$login =~ s/^\s+|\s+$//g;

# =========================================================
# CONTADOR FALLOS
# =========================================================

my $fallos =
    $cgi->param('fallos') || 0;

# =========================================================
# VALIDACION CAMPOS
# =========================================================

unless (
    $login &&
    $password
) {

    print qq{

<!DOCTYPE html>

<html>

<head>

<meta http-equiv="refresh"
content="0; url=/index.html?error=1&fallos=$fallos">

</head>

<body>

Redirigiendo...

</body>

</html>

    };

    exit;
}

# =========================================================
# DB
# =========================================================

my $dbh =
    conexion::conectar();

# =========================================================
# BUSCAR USUARIO
# =========================================================

my $sth = $dbh->prepare(q{

SELECT
    login,
    password,
    activo
FROM usuarios
WHERE login = ?

});

$sth->execute($login);

my $user =
    $sth->fetchrow_hashref();

# =========================================================
# LOGIN INVALIDO
# =========================================================

unless (
    $user
    &&
    $user->{activo}
    &&
    crypt(
        $password,
        $user->{password}
    ) eq $user->{password}
) {

    $fallos++;

    $sth->finish();

    $dbh->disconnect();

    print qq{

<!DOCTYPE html>

<html>

<head>

<meta http-equiv="refresh"
content="0; url=/index.html?error=1&fallos=$fallos">

</head>

<body>

Redirigiendo...

</body>

</html>

    };

    exit;
}

# =========================================================
# LOGIN OK
# =========================================================

$sth->finish();

$dbh->disconnect();

print qq{

<!DOCTYPE html>

<html>

<head>

<meta http-equiv="refresh"
content="0; url=/~$login">

</head>

<body>

Redirigiendo...

</body>

</html>

};
