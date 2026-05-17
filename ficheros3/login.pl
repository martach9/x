#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use CGI::Session;
use Authen::Simple::PAM;

require "/var/www/cgi-bin/conexion.pl";

my $cgi = CGI->new();

CGI::Session->name("ECOSESSION");

my $session = CGI::Session->new(
    undef,
    $cgi,
    { Directory => '/var/lib/ecosalmantica/sessions' }
);

if ($session->param('autenticado')) {
    my $usuario = $session->param('usuario');
    print $cgi->redirect("/~$usuario/");
    exit;
}

unless (($cgi->request_method() || '') eq 'POST') {
    print $cgi->redirect('/');
    exit;
}

my $login    = $cgi->param('login')    // '';
my $password = $cgi->param('password') // '';
my $fallos   = $cgi->param('fallos')   // 0;

$fallos = int($fallos);
$login =~ s/^\s+|\s+$//g;

unless ($login =~ /^[a-z_][a-z0-9_-]{2,31}$/ && $password ne '') {
    print $cgi->redirect("/?error=1&fallos=" . ($fallos + 1));
    exit;
}

my $pendiente = "/var/ecosalmantica/pendientes/$login.req";

if (-e $pendiente) {
    print $cgi->redirect("/?error=pendiente&fallos=" . ($fallos + 1));
    exit;
}

my $dbh = conexion::conectar();

my $sth = $dbh->prepare(q{
    SELECT activo, procesado
    FROM usuarios
    WHERE login = ?
});

$sth->execute($login);

my $u = $sth->fetchrow_hashref();

$sth->finish();
$dbh->disconnect();

unless ($u && $u->{activo} == 1 && $u->{procesado} == 1) {
    print $cgi->redirect("/?error=noactivo&fallos=" . ($fallos + 1));
    exit;
}

my $auth = Authen::Simple::PAM->new(
    service => 'login'
);

if ($auth->authenticate($login, $password)) {

    $session->param('autenticado', 1);
    $session->param('usuario', $login);
    $session->expire('+1h');

    print $cgi->redirect(
        -uri    => "/~$login/",
        -cookie => $session->cookie()
    );

    exit;
}
else {
    print $cgi->redirect("/?error=1&fallos=" . ($fallos + 1));
    exit;
}
