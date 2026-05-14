#!/usr/bin/perl

use strict;
use warnings;
use Quota;
use Linux::usermod;
use File::Path qw(remove_tree);

require "/usr/lib/cgi-bin/conexion.pl";

# =========================================================
# DB
# =========================================================

my $dbh = conexion::conectar();

# =========================================================
# USUARIOS CON BAJA
# =========================================================

my $sth = $dbh->prepare(q{

SELECT
    login
FROM usuarios
WHERE baja = 1

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

    my $home =
        "/home/$login";

    eval {

        # =================================================
        # ELIMINAR HOME
        # =================================================

        if (-d $home) {

            remove_tree($home);
        }

	# =================================================
	# ELIMINAR QUOTA
	# =================================================

	my @pw = getpwnam($login);

	if (@pw) {

	    my $uid = $pw[2];
	
	    Quota::setqlim(
	        Quota::getqcarg('/'),
	        $uid,
	        0,
	        0,
	        0,
	        0
	    );
	}
        # =================================================
        # ELIMINAR USUARIO LINUX
        # =================================================

        Linux::usermod->del($login);

        # =================================================
        # ELIMINAR BD
        # =================================================

        my $del = $dbh->prepare(q{

        DELETE FROM usuarios
        WHERE login = ?

        });

        $del->execute($login);
    };

    if ($@) {

        warn "Error eliminando $login: $@";
    }
}

# =========================================================
# FIN
# =========================================================

$sth->finish();

$dbh->disconnect();
