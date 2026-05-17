#!/usr/bin/perl

use strict;
use warnings;
use CGI qw(:standard);
use JSON;

my $cgi = CGI->new;

print $cgi->header(
    -type    => 'application/json',
    -charset => 'UTF-8',
    -access_control_allow_origin => '*',
);

my $login = $cgi->param('login') || '';
my $limit = $cgi->param('limit') || 5;

$login =~ s/^\s+|\s+$//g;
$limit =~ s/[^0-9]//g;
$limit = 10 if $limit > 10;
$limit = 1  if $limit < 1;

unless ( length($login) && $login =~ /^[a-zA-Z0-9._-]+$/ ) {
    print encode_json({ error => 'Login invalido', posts => [] });
    exit;
}

my $blog_dir = "/home/$login/public_html/blog/posts";

unless ( -d $blog_dir ) {
    print encode_json({ error => 'Blog no encontrado', posts => [] });
    exit;
}

opendir( my $dh, $blog_dir ) or do {
    print encode_json({ error => 'No se pudo abrir directorio', posts => [] });
    exit;
};

my @archivos =
    sort { $b cmp $a }
    grep { /^post_\d+\.txt$/ }
    readdir($dh);

closedir($dh);

my @posts;

for my $archivo ( @archivos ) {
    last if scalar(@posts) >= $limit;

    my $ruta = "$blog_dir/$archivo";
    open( my $fh, '<:encoding(UTF-8)', $ruta ) or next;
    my @lineas = <$fh>;
    close($fh);
    chomp @lineas;

    my $autor   = $lineas[0] // 'Anonimo';
    my $fecha   = $lineas[1] // '';
    my $titulo  = $lineas[2] // 'Sin titulo';
    my $mensaje = '';
    if ( scalar(@lineas) > 4 ) {
        $mensaje = join("\n", @lineas[4..$#lineas]);
    }

    my $extracto = $mensaje;
    $extracto =~ s/\n/ /g;
    if ( length($extracto) > 160 ) {
        $extracto = substr($extracto, 0, 160) . '...';
    }

    my ($timestamp) = $archivo =~ /^post_(\d+)\.txt$/;

    push @posts, {
        id       => $timestamp + 0,
        archivo  => $archivo,
        autor    => $autor,
        fecha    => $fecha,
        titulo   => $titulo,
        extracto => $extracto,
        mensaje  => $mensaje,
    };
}

print encode_json({
    login => $login,
    total => scalar(@archivos),
    posts => \@posts,
});
