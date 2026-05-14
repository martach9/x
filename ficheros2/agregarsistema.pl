#!/usr/bin/perl

use strict;
use warnings;

use Linux::usermod;
use File::Copy qw(copy);
use Fcntl qw(:DEFAULT :flock);
use Quota;

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
    nombre,
    email,
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

    my $login =
        $u->{login};
    
    my $nombre =
        $u->{nombre};

    my $email =
       $u->{email};

    my $password_linux =
        $u->{password_linux};

    next unless defined $password_linux;

    my $tipo =
        $u->{tipo};

    # =====================================================
    # CONFIG
    # =====================================================

    my $home =
        "/home/$login";

    my $shell =
        '/bin/bash';

    my $gid =
        ($tipo eq 'operario')
        ? 1002
        : 1001;

    eval {

        # =================================================
        # SI YA EXISTE
        # =================================================

        unless (getpwnam($login)) {

            # =============================================
            # CREAR USER
            # =============================================

            my $ok = Linux::usermod->add(
                $login,
                'x',
                '',
                $gid,
                '',
                $home,
                $shell
            );

            die "Error creando usuario"
                unless $ok;

            # =============================================
# ACTUALIZAR /etc/shadow
# =============================================

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

foreach my $linea (@lineas) {

    chomp($linea);

    my @campos =
        split(/:/, $linea, 9);

    if ($campos[0] eq $login) {

        $campos[1] =
            $password_linux;

        $linea =
            join(':', @campos);
    }

    print $shadow_fh "$linea\n";
}

close($shadow_fh);
        }

        # =================================================
        # UID/GID
        # =================================================

        my @pw =
            getpwnam($login);

        die "No existe usuario"
            unless @pw;
	

        my $uid =
            $pw[2];

        my $gid_real =
            $pw[3];
	
	unless (-d $home) {

    mkdir($home)
        or die "No se pudo crear HOME";
}
        # =================================================
        # HOME PERMISOS
        # =================================================

        chmod(
            0755,
            $home
        );

        chown(
            $uid,
            $gid_real,
            $home
        );

# =================================================
        # public_html
        # =================================================

        unless (
            -d "$home/public_html"
        ) {

            mkdir(
                "$home/public_html"
            ) or die "No se pudo crear public_html";
        }

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

	if ($tipo eq 'ciudadano') {

	    # =============================================
	    # carpeta blog

	    unless (
	        -d "$home/blog"
	    ) {

	        mkdir(
	            "$home/blog"
	        ) or die "No se pudo crear blog";
	    }

	    chmod(
	        0755,
	        "$home/blog"
	    );

	    chown(
	        $uid,
	        $gid_real,
	        "$home/blog"
	    );

	    # =============================================
	    # carpeta posts
	    # =============================================

	    unless (
		    -d "$home/blog/posts"
		) {

		    mkdir(
		        "$home/blog/posts"
		    ) or die "No se pudo crear posts";
		}

		chmod(
		    0777,
		    "$home/blog/posts"
		);

		chown(
		    $uid,
		    $gid_real,
		    "$home/blog/posts"
		);
	}

        # =================================================
        # COPIAR index.html DESDE SKEL
        # =================================================

        copy(
            "/etc/skel/public_html/index.html",
            "$home/public_html/index.html"
        ) or die "No se pudo copiar index";

        chmod(
            0644,
            "$home/public_html/index.html"
        );

        chown(
            $uid,
            $gid_real,
            "$home/public_html/index.html"
        );

        # =================================================
        # PERSONALIZAR index.html
        # =================================================

        my $index =
            "$home/public_html/index.html";

        open(
            my $fh,
            '<',
            $index
        ) or die "No se pudo abrir index";

        my $html = do {

            local $/;
            <$fh>
        };

        close($fh);

        # =============================================
        # REEMPLAZOS
        # =============================================

        $html =~ s/__LOGIN__/$login/g;

        $html =~ s/__HOME__/$home/g;

        $html =~ s/__WEB__/https:\/\/192.168.56.107\/~$login/g;

	$html =~ s/__NOMBRE__/$nombre/g;

	$html =~ s/__EMAIL__/$email/g;

	# =============================================
	# MANUALES SOLO OPERARIOS
	# =============================================

	my $manuales = '';

	if ($tipo eq 'operario') {

	    $manuales = qq{

	<hr>

	<a
	href="/cgi-bin/manuales.pl?login=$login"
	target="_blank">

	<i class="fas fa-hard-hat"></i>

	Manuales SmartCity
	
	</a>

	    };
	}

	$html =~ s/__MANUALES__/$manuales/g;
        # =============================================
        # GUARDAR index
        # =============================================

        open(
            my $out,
            '>',
            $index
        ) or die "No se pudo escribir index";

        print $out $html;

        close($out);

        chmod(
            0644,
            $index
        );

        chown(
            $uid,
            $gid_real,
            $index
        );
	# =================================================
	# CUOTAS
	# =================================================

	my $bloques_soft;
	my $bloques_hard;

	if ($tipo eq 'operario') {

	    # 300 MB
	
	    $bloques_soft = 307200;
	    $bloques_hard = 307200;
	}
	else {

	    # 100 MB
	
	    $bloques_soft = 102400;
	    $bloques_hard = 102400;
	}

	Quota::setqlim(
	    Quota::getqcarg('/'),
	    $uid,
	    $bloques_soft,
	    $bloques_hard,
	    0,
	    0
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

$sth->finish();

$dbh->disconnect();
