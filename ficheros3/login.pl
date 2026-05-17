#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use CGI::Session;
use Authen::Simple::PAM;

require "/var/www/cgi-bin/conexion.pl";

my $cgi = CGI->new();

CGI::Session->name("ECOSESSION");

sub mostrar_panel {
    my ($login) = @_;

    unless ($login =~ /^[a-z_][a-z0-9_-]{2,31}$/) {
        print "<h2>Usuario inválido</h2>";
        return;
    }

    my $panel = "/home/$login/panel/index.html";

    unless (-f $panel) {
        print "<h2>Error</h2>";
        print "<p>No existe el panel del usuario.</p>";
        return;
    }

    open my $fh, '<', $panel
        or do {
            print "<h2>Error</h2>";
            print "<p>No se pudo abrir el panel.</p>";
            return;
        };

    local $/;
    my $html = <$fh>;

    close $fh;

    print $html;
}

my $session = CGI::Session->new(
    undef,
    $cgi,
    { Directory => '/var/lib/ecosalmantica/sessions' }
);

# =========================
# PETICIONES GET
# =========================

unless (($cgi->request_method() || '') eq 'POST') {

    if ($session->param('autenticado')) {

        print $cgi->header(
            -type    => 'text/html',
            -charset => 'UTF-8'
        );

        mostrar_panel($session->param('usuario'));
        exit;
    }

    print $cgi->redirect('/');
    exit;
}

# =========================
# LOGIN NUEVO (POST)
# =========================

# Destruir cualquier sesión previa
if ($session->param('autenticado')) {

    $session->delete();
    $session->flush();

    # Crear sesión completamente nueva
    $session = CGI::Session->new(
        undef,
        undef,
        { Directory => '/var/lib/ecosalmantica/sessions' }
    );
}

my $login    = $cgi->param('login')    // '';
my $password = $cgi->param('password') // '';
my $fallos   = $cgi->param('fallos')   // 0;

$fallos = int($fallos);

$login =~ s/^\s+|\s+$//g;

unless ($login =~ /^[a-z_][a-z0-9_-]{2,31}$/ && $password ne '') {

    print $cgi->redirect(
        "/?error=1&fallos=" . ($fallos + 1)
    );

    exit;
}

my $pendiente = "/var/ecosalmantica/pendientes/$login.req";

if (-e $pendiente) {

    print $cgi->redirect(
        "/?error=pendiente&fallos=" . ($fallos + 1)
    );

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

    print $cgi->redirect(
        "/?error=noactivo&fallos=" . ($fallos + 1)
    );

    exit;
}

my $auth = Authen::Simple::PAM->new(
    service => 'login'
);

if ($auth->authenticate($login, $password)) {

    # Regenerar sesión limpia
    $session->delete();
    $session->flush();

    $session = CGI::Session->new(
        undef,
        undef,
        { Directory => '/var/lib/ecosalmantica/sessions' }
    );

    $session->param('autenticado', 1);
    $session->param('usuario', $login);

    $session->expire('+1h');

    $session->flush();

    print $cgi->header(
        -type    => 'text/html',
        -charset => 'UTF-8',
        -cookie  => $session->cookie()
    );

    mostrar_panel($login);

    exit;
}
else {

    print $cgi->redirect(
        "/?error=1&fallos=" . ($fallos + 1)
    );

    exit;
}
