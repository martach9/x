#!/usr/bin/perl

use strict;
use warnings;
use CGI qw(:standard);
use JSON::PP;

print header(
    -type => 'application/json',
    -charset => 'UTF-8',
    -access_control_allow_origin => '*'
);

# =========================
# CPU
# =========================

my $cpu = `top -bn1 | grep "Cpu(s)"`;
my ($cpu_idle) = $cpu =~ /(\d+\.\d+)\s*id/;

$cpu_idle ||= 0;

my $cpu_usage = int(100 - $cpu_idle);

# =========================
# RAM
# =========================

my $ram = `free | grep Mem`;

my @ram_values = split(/\s+/, $ram);

my $total_ram = $ram_values[1];
my $used_ram  = $ram_values[2];

my $ram_percent = int(($used_ram / $total_ram) * 100);

# =========================
# DISCO
# =========================

my $disk = `df -h / | tail -1`;

my @disk_values = split(/\s+/, $disk);

my $disk_percent = $disk_values[4];

$disk_percent =~ s/%//;

# =========================
# JSON
# =========================

my %data = (
    cpu_percent  => $cpu_usage,
    ram_percent  => $ram_percent,
    disk_percent => $disk_percent
);

print encode_json(\%data);
