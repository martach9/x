#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard);

require "/var/www/cgi-bin/conexion.pl";

my $cgi = CGI->new;

my $post_id =
    $cgi->param('post_id');

my $autor =
    $cgi->param('autor');

my $comentario =
    $cgi->param('comentario');

my $dbh =
    conexion::conectar();

my $sth = $dbh->prepare(q{

INSERT INTO comentarios
(post_id,autor,comentario)
VALUES (?,?,?)

});

$sth->execute(
    $post_id,
    $autor,
    $comentario
);

$sth->finish();

print $cgi->redirect(
    $ENV{'HTTP_REFERER'}
);

$dbh->disconnect();
