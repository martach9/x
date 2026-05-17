#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use CGI::Session;

my $cgi = CGI->new;

my $session = CGI::Session->new(
    undef,
    $cgi,
    { Directory => '/tmp' }
);

$session->delete();

$session->flush();

print $cgi->redirect(
    "/index.html"
);
