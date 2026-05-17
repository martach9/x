#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use CGI::Session;

my $cgi = CGI->new;

CGI::Session->name("ECOSESSION");

my $session = CGI::Session->new(
    undef,
    $cgi,
    { Directory => '/var/lib/ecosalmantica/sessions' }
);

$session->delete();
$session->flush();

my $cookie = $cgi->cookie(
    -name    => 'ECOSESSION',
    -value   => '',
    -expires => '-1d',
    -path    => '/'
);

print $cgi->redirect(
    -uri    => '/',
    -cookie => $cookie
);
