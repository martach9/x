#!/usr/bin/perl
use strict;
use warnings;
use CGI qw(:standard);
use JSON::PP;
use Filesys::Df;
use Sys::MemInfo qw(totalmem freemem);

print header(
    -type                        => 'application/json',
    -charset                     => 'UTF-8',
    -access_control_allow_origin => '*'
);

# =========================
# CPU (leyendo /proc/stat)
# =========================
sub get_cpu_usage {
    my %read_stat = read_proc_stat();
    sleep(1);
    my %read_stat2 = read_proc_stat();

    my $idle1  = $read_stat{idle}  + $read_stat{iowait};
    my $idle2  = $read_stat2{idle} + $read_stat2{iowait};
    my $total1 = $read_stat{total};
    my $total2 = $read_stat2{total};

    my $diff_total = $total2 - $total1;
    my $diff_idle  = $idle2  - $idle1;

    return $diff_total > 0 ? int(100 * (1 - $diff_idle / $diff_total)) : 0;
}

sub read_proc_stat {
    open(my $fh, '<', '/proc/stat') or die "No puedo leer /proc/stat: $!";
    my $line = <$fh>;
    close($fh);

    my (undef, $user, $nice, $system, $idle, $iowait, $irq, $softirq) = split(/\s+/, $line);
    my $total = $user + $nice + $system + $idle + $iowait + $irq + $softirq;

    return (
        idle   => $idle,
        iowait => $iowait,
        total  => $total
    );
}

# =========================
# RAM con Sys::MemInfo
# =========================
sub get_ram_usage {
    my $total = totalmem();
    my $free  = freemem();
    return $total > 0 ? int(($total - $free) / $total * 100) : 0;
}

# =========================
# DISCO con Filesys::Df
# =========================
sub get_disk_usage {
    my $df = df("/") or die "No puedo leer el disco: $!";
    return int($df->{per});
}

# =========================
# JSON
# =========================
my %data = (
    cpu_percent  => get_cpu_usage(),
    ram_percent  => get_ram_usage(),
    disk_percent => get_disk_usage()
);

print encode_json(\%data);
