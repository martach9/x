#!/usr/bin/perl

use strict;
use warnings;

use Linux::usermod;
use File::Copy qw(copy);
use File::Path qw(make_path);

require "/usr/lib/cgi-bin/conexion.pl";

# =========================================================
# DB
# =========================================================

my $dbh = conexion::conectar();

# =========================================================
# BUSCAR USUARIOS ACTIVOS
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
# RECORRER USUARIOS
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
    # SI YA EXISTE -> marcar procesado
    # =====================================================

    if (getpwnam($login)) {

        my $up = $dbh->prepare(q{

        UPDATE usuarios
        SET procesado = 1
        WHERE login = ?

        });

        $up->execute($login);

        next;
    }

    # =====================================================
    # HOME
    # =====================================================

    my $home = "/home/$login";

    # =====================================================
    # SHELL
    # =====================================================

    my $shell =
        ($tipo eq 'operario')
        ? '/bin/bash'
        : '/usr/sbin/nologin';

    # =====================================================
    # GID
    # =====================================================

    my $gid_sistema =
        ($tipo eq 'operario')
        ? 1002
        : 1001;

    eval {

        # =================================================
        # CREAR USUARIO
        # =================================================

        my $ok = Linux::usermod->add(
            $login,
            $password_linux,
            '',
            $gid_sistema,
            '',
            $home,
            $shell
        );

        die "Error creando usuario"
            unless $ok;

        # =================================================
        # OBTENER UID/GID
        # =================================================

        my @pw = getpwnam($login);

        die "Usuario no encontrado"
            unless @pw;

        my $uid = $pw[2];
        my $gid = $pw[3];

        # =================================================
        # HOME
        # =================================================

        unless (-d $home) {

            mkdir($home)
                or die "No se pudo crear home";
        }

        chmod(0755, $home);

        chown($uid, $gid, $home);

        # =================================================
        # SKEL
        # =================================================

        copy(
            "/etc/skel/.bashrc",
            "$home/.bashrc"
        );

        copy(
            "/etc/skel/.profile",
            "$home/.profile"
        );

        copy(
            "/etc/skel/.bash_logout",
            "$home/.bash_logout"
        );

        chown(
            $uid,
            $gid,
            "$home/.bashrc",
            "$home/.profile",
            "$home/.bash_logout"
        );

        # =================================================
        # public_html
        # =================================================

        my $public =
            "$home/public_html";

        mkdir($public);

        chmod(0755, $public);

        chown($uid, $gid, $public);

        # =================================================
        # blog
        # =================================================

        my $blog =
            "$home/blog";

        mkdir($blog);

        chmod(0755, $blog);

        chown($uid, $gid, $blog);

        # =================================================
        # MARCAR PROCESADO
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
# CERRAR
# =========================================================

$dbh->disconnect();
