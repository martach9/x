#!/usr/bin/perl

use strict;
use warnings;

use Fcntl qw(:DEFAULT :flock);

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
    password_nueva_linux
FROM usuarios
WHERE passwdPendiente = 1

});

$sth->execute();

# =========================================================
# RECORRER
# =========================================================

while (
    my $u = $sth->fetchrow_hashref()
) {

    my $login =
        $u->{login};

    my $nuevo_hash =
        $u->{password_nueva_linux};

    next unless (
        defined $nuevo_hash
        &&
        $nuevo_hash ne ''
    );

    eval {

        # =================================================
        # ABRIR SHADOW
        # =================================================

        sysopen(
            my $shadow_fh,
            '/etc/shadow',
            O_RDWR
        ) or die "No se pudo abrir shadow";

        flock(
            $shadow_fh,
            LOCK_EX
        ) or die "No se pudo bloquear shadow";

        my @lineas = <$shadow_fh>;

        seek($shadow_fh, 0, 0);

        truncate($shadow_fh, 0);

        # =============================================
        # ACTUALIZAR SHADOW
        # =============================================

        foreach my $linea (@lineas) {

            chomp($linea);

            my @campos =
                split(/:/, $linea, 9);

            if ($campos[0] eq $login) {

                $campos[1] =
                    $nuevo_hash;

                $linea =
                    join(':', @campos);
            }

            print $shadow_fh "$linea\n";
        }

        close($shadow_fh);

        # =================================================
        # ACTUALIZAR DB
        # =================================================

        my $up = $dbh->prepare(q{

        UPDATE usuarios
        SET
            password = ?,
            password_linux = ?,
            password_nueva_linux = NULL,
            passwdPendiente = 0
        WHERE login = ?

        });

        $up->execute(

            $nuevo_hash,
            $nuevo_hash,
            $login

        );

        $up->finish();
    };

    if ($@) {

        warn "Error actualizando password de $login: $@";
    }
}

# =========================================================
# FIN
# =========================================================

$sth->finish();

$dbh->disconnect();
