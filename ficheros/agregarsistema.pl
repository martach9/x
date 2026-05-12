#!/usr/bin/perl

use strict;
use warnings;

use Linux::usermod;
use File::Copy qw(copy);

require "/usr/lib/cgi-bin/conexion.pl";

# =========================================================
# DB
# =========================================================

my $dbh = conexion::conectar();

# =========================================================
# USUARIOS PENDIENTES
# =========================================================

my $sth = $dbh->prepare(q{

SELECT
    login,
    password_linux,
    tipo
FROM usuarios
WHERE activo = 1
AND procesado = 0

});

$sth->execute();

# =========================================================
# RECORRER
# =========================================================

while (
    my $u = $sth->fetchrow_hashref()
) {

    my $login = $u->{login};

    my $password_linux =
        $u->{password_linux};

    my $tipo =
        $u->{tipo};

    # =====================================================
    # SI YA EXISTE
    # =====================================================

    next if getpwnam($login);

    # =====================================================
    # CONFIG
    # =====================================================

    my $home = "/home/$login";

    my $shell =
        ($tipo eq 'operario')
        ? '/bin/bash'
        : '/usr/sbin/nologin';

    my $gid =
        ($tipo eq 'operario')
        ? 1002
        : 1001;

    eval {

        # =================================================
        # CREAR USER
        # =================================================

        my $ok = Linux::usermod->add(
            $login,
            $password_linux,
            '',
            $gid,
            '',
            $home,
            $shell
        );

        die "Error creando usuario"
            unless $ok;

        # =================================================
        # UID/GID
        # =================================================

        my @pw = getpwnam($login);

        die "No existe usuario"
            unless @pw;

        my $uid = $pw[2];
        my $gid_real = $pw[3];

        # =================================================
        # public_html
        # =================================================

        mkdir("$home/public_html");

        chmod(
            0755,
            "$home/public_html"
        );

        chown(
            $uid,
            $gid_real,
            "$home/public_html"
        );

        # =================================================
        # blog
        # =================================================

        mkdir("$home/blog");

        chmod(
            0755,
            "$home/blog"
        );

        chown(
            $uid,
            $gid_real,
            "$home/blog"
        );

        # =================================================
        # PROCESADO
        # =================================================

        my $up = $dbh->prepare(q{

        UPDATE usuarios
        SET procesado = 1
        WHERE login = ?

        });

        $up->execute($login);
    };

    if ($@) {

        warn "Error con $login: $@";
    }
}

# =========================================================
# FIN
# =========================================================

$dbh->disconnect();
