#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use CGI::Carp qw(fatalsToBrowser);

require "/var/www/cgi-bin/conexion.pl";

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

my $login = $cgi->param('login') || '';
$login =~ s/^\s+|\s+$//g;

# =========================================================
# VALIDACION
# =========================================================

unless ($login) {
    print "<h2>Error</h2><p>Usuario inválido.</p>";
    exit;
}

# =========================================================
# DB
# =========================================================

my $dbh = conexion::conectar();

# =========================================================
# BUSCAR USUARIO
# =========================================================

my $sth = $dbh->prepare(q{
    SELECT login, nombre, email, direccion, tipo
    FROM usuarios
    WHERE login = ?
});

$sth->execute($login);

my $user = $sth->fetchrow_hashref();

unless ($user) {
    print "<h2>Error</h2><p>Usuario no encontrado.</p>";
    exit;
}

# =========================================================
# ESCAPAR DATOS
# =========================================================

my $login_safe     = escapeHTML($user->{login} // '');
my $nombre_safe    = escapeHTML($user->{nombre} // '');
my $email_safe     = escapeHTML($user->{email} // '');
my $direccion_safe = escapeHTML($user->{direccion} // '');
my $tipo_safe      = escapeHTML($user->{tipo} // '');

# =========================================================
# INICIALES PARA AVATAR
# =========================================================

my @partes = split /\s+/, ($user->{nombre} // '');

my $iniciales_safe = '';

foreach my $p (@partes[0..1]) {

    next unless defined $p;
    next unless length($p);

    $iniciales_safe .= uc(substr($p, 0, 1));
}

$iniciales_safe = escapeHTML($iniciales_safe);

# =========================================================
# CARGAR PLANTILLA
# =========================================================

my $template_path = '/var/www/html/datosPersonales.html';

open(my $fh, '<:encoding(UTF-8)', $template_path)
    or die "No se pudo abrir la plantilla: $!";

my $html = do {
    local $/;
    <$fh>;
};

close($fh);

# =========================================================
# SUSTITUIR MARCADORES
# =========================================================

$html =~ s/\{\{LOGIN\}\}/$login_safe/g;
$html =~ s/\{\{NOMBRE\}\}/$nombre_safe/g;
$html =~ s/\{\{EMAIL\}\}/$email_safe/g;
$html =~ s/\{\{DIRECCION\}\}/$direccion_safe/g;
$html =~ s/\{\{TIPO\}\}/$tipo_safe/g;
$html =~ s/\{\{INICIALES\}\}/$iniciales_safe/g;

# =========================================================
# IMPRIMIR HTML
# =========================================================

print $html;

# =========================================================
# CERRAR DB
# =========================================================

$sth->finish();
$dbh->disconnect();
