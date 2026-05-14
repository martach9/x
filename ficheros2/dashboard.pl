#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard);
use IO::Socket::INET;
use JSON;

print header('application/json');

sub comprobar_servicio {

    my ($puerto) = @_;

    my $socket = IO::Socket::INET->new(

        PeerAddr => '127.0.0.1',
        PeerPort => $puerto,
        Proto    => 'tcp',
        Timeout  => 2

    );

    return $socket ? 1 : 0;
}

my %estado = (

    web     => comprobar_servicio(443),
    correo  => comprobar_servicio(25),
    ftp     => comprobar_servicio(21),
    mysql   => comprobar_servicio(3306),

);

print encode_json(\%estado);
