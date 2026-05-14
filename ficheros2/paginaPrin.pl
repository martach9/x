#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use CGI::Session;
use DBI;
use Digest::SHA qw(sha256_hex);
use Unix::Passwd::File;
use Crypt::PasswdMD5 qw(unix_md5_crypt);
use File::Path qw(remove_tree);

require "/usr/lib/cgi-bin/conexion.pl";

# =========================================================
# CONFIGURACIÓN
# =========================================================

my $SESSION_DIR = "/tmp/cgisessions";
my $MANUALES_DIR = "/manuales_smartcity";

# =========================================================
# INICIALIZACIÓN CGI
# =========================================================

my $cgi = CGI->new;

# =========================================================
# SESIÓN SEGURA
# =========================================================

my $session = CGI::Session->load(
    undef,
    $cgi,
    { Directory => $SESSION_DIR }
);

if ($session->is_empty || $session->is_expired) {

    print $cgi->redirect('/index.html');
    exit;
}

my $usuario = $session->param('usuario') || '';

# Validación estricta usuario Linux
unless ($usuario =~ /^[a-z_][a-z0-9_-]*$/) {

    $session->delete();
    print $cgi->redirect('/index.html');
    exit;
}

my $usuario_safe = escapeHTML($usuario);

# =========================================================
# CONEXIÓN DB
# =========================================================

my $dbh = conexion::conectar();

# =========================================================
# DATOS USUARIO
# =========================================================

my $sth_user = $dbh->prepare(
    "SELECT tipo FROM usuarios WHERE login = ?"
);

$sth_user->execute($usuario);

my ($tipo) = $sth_user->fetchrow_array();

unless ($tipo) {

    $session->delete();
    print $cgi->redirect('/index.html');
    exit;
}

my $tipo_safe = escapeHTML($tipo);

# =========================================================
# SECCIÓN
# =========================================================

my $seccion = $cgi->param('seccion') || 'inicio';

# =========================================================
# TOKEN CSRF
# =========================================================

my $csrf_token = $session->param('csrf_token');

unless ($csrf_token) {

    $csrf_token = sha256_hex(rand() . time() . $$);

    $session->param(
        'csrf_token',
        $csrf_token
    );

    $session->flush();
}

sub validar_csrf {

    my $token = shift || '';

    return (
        defined $token
        &&
        $token eq $csrf_token
    );
}

# =========================================================
# HEADER
# =========================================================

print $cgi->header(
    -type    => 'text/html',
    -charset => 'UTF-8'
);

# =========================================================
# HTML INICIO
# =========================================================

print qq{
<!DOCTYPE html>
<html lang="es">

<head>

<meta charset="UTF-8">

<title>EcoSalmantica - Panel</title>

<style>

body{
    margin:0;
    font-family:'Segoe UI',Arial,sans-serif;
    background:#13232f;
    color:white;
}

.topbar{
    background:#1c3a4a;
    padding:15px 25px;
    display:flex;
    justify-content:space-between;
    align-items:center;
    border-bottom:2px solid #1ab188;
}

.container{
    display:flex;
    min-height:100vh;
}

.sidebar{
    width:220px;
    background:#1c2b36;
    padding:20px;
    border-right:1px solid #2d3e4a;
}

.content{
    flex:1;
    padding:40px;
}

.card{
    background:#24333e;
    padding:25px;
    border-radius:8px;
    margin-bottom:20px;
}

.sidebar a{
    color:#4eb5f1;
    text-decoration:none;
    display:block;
    padding:10px;
    margin:5px 0;
}

.sidebar a:hover{
    background:#2d3e4a;
}

button{
    background:#1ab188;
    color:white;
    border:none;
    padding:12px 20px;
    cursor:pointer;
    border-radius:4px;
    font-weight:bold;
}

button:hover{
    background:#17a07b;
}

.btn-danger{
    background:#e74c3c;
}

.btn-danger:hover{
    background:#c0392b;
}

input{
    width:100%;
    padding:10px;
    margin:10px 0;
    border-radius:4px;
    border:1px solid #1c3a4a;
    background:#13232f;
    color:white;
    box-sizing:border-box;
}

code{
    background:#000;
    padding:4px;
    color:#1ab188;
}

.item-file{
    padding:10px;
    border-bottom:1px solid #1c3a4a;
    display:flex;
    justify-content:space-between;
}

</style>

</head>

<body>

<div class="topbar">

<span>
EcoSalmantica |
<b>Panel de Gestión</b>
</span>

<span>
Rol:
<b style="color:#1ab188;">$tipo_safe</b>
|
Usuario:
<b>$usuario_safe</b>
</span>

</div>

<div class="container">

<div class="sidebar">

<a href="?seccion=inicio">🏠 Inicio</a>

<a href="?seccion=password">🔑 Contraseña</a>
};

# =========================================================
# MENÚ POR ROL
# =========================================================

if ($tipo eq 'ciudadano') {

    print qq{

<a href="?seccion=web">🌐 Mi Web Personal</a>

<a href="?seccion=blog">✍️ Mi Blog</a>

};

}
elsif ($tipo eq 'operario') {

    print qq{

<a href="?seccion=manuales" style="color:#f1c40f;">
🛠️ Manuales SmartCity
</a>

};

}

print qq{

<a href="?seccion=baja"
style="color:#e74c3c;margin-top:50px;">

⚠️ Dar de Baja

</a>

<a href="logout.pl"
style="margin-top:20px;border-top:1px solid #2d3e4a;">

🚪 Cerrar Sesión

</a>

</div>

<div class="content">

};

# =========================================================
# INICIO
# =========================================================

if ($seccion eq 'inicio') {

    print qq{

<h2>Bienvenido al sistema, $usuario_safe</h2>

<div class="card">

<p>
Acceso concedido como
<b>$tipo_safe</b>.
</p>

<p>
Tu espacio personal:
<code>/home/$usuario_safe</code>
</p>

<p>
Usa el menú lateral para gestionar tus servicios.
</p>

</div>

};
}

# =========================================================
# FORM PASSWORD
# =========================================================

elsif ($seccion eq 'password') {

    print qq{

<div class="card">

<h2>Cambiar Contraseña</h2>

<form method="POST"
action="?seccion=update_password">

<input type="hidden"
name="csrf_token"
value="$csrf_token">

<label>Nueva Contraseña:</label>

<input type="password"
name="new_pass"
required>

<button type="submit">
Actualizar Contraseña
</button>

</form>

</div>

};
}

# =========================================================
# UPDATE PASSWORD
# =========================================================

elsif ($seccion eq 'update_password') {

    my $token = $cgi->param('csrf_token') || '';

    unless (validar_csrf($token)) {

        print qq{
        <div class="card">
        Token CSRF inválido.
        </div>
        };

    }
    else {

        my $new_plain =
            $cgi->param('new_pass') || '';

        if (length($new_plain) < 8) {

            print qq{
            <div class="card">
            La contraseña debe tener mínimo 8 caracteres.
            </div>
            };

        }
        else {

            # =========================
            # HASH WEB
            # =========================

            my $new_salt = int(rand(999999));

            my $new_hash =
                sha256_hex(
                    $new_plain . $new_salt
                );

            my $sth = $dbh->prepare(
                "UPDATE usuarios
                 SET password=?,
                     saltHash=?
                 WHERE login=?"
            );

            $sth->execute(
                $new_hash,
                $new_salt,
                $usuario
            );

            # =========================
            # HASH LINUX
            # =========================

            my $linux_salt =
                substr(time(), -8);

            my $linux_hash =
                unix_md5_crypt(
                    $new_plain,
                    $linux_salt
                );

            my $shadow =
                Unix::Passwd::File->new(
                    '/etc/shadow'
                );

            eval {

                if ($shadow->user($usuario)) {

                    $shadow->passwd(
                        $usuario,
                        $linux_hash
                    );

                    $shadow->commit();
                }
            };

            print qq{

<div class="card">

✅ Contraseña actualizada correctamente.

</div>

};
        }
    }
}

# =========================================================
# MANUALES
# =========================================================

elsif (
    $seccion eq 'manuales'
    &&
    $tipo eq 'operario'
) {

    print qq{

<div class="card">

<h2>🛠️ Manuales SmartCity</h2>

<p>
Ruta:
<code>$MANUALES_DIR</code>
</p>

<hr>

};

    if (opendir(my $dh, $MANUALES_DIR)) {

        while (my $file = readdir($dh)) {

            next if $file =~ /^\./;

            next unless
                $file =~ /^[a-zA-Z0-9._-]+$/;

            my $safe_file =
                escapeHTML($file);

            print qq{

<div class="item-file">

<span>📄 $safe_file</span>

<a href="?seccion=borrar_file&file=$safe_file">

Eliminar

</a>

</div>

};
        }

        closedir($dh);

    }
    else {

        print qq{
        <p>No hay manuales disponibles.</p>
        };
    }

    print qq{
</div>
};
}

# =========================================================
# BORRAR MANUAL
# =========================================================

elsif (
    $seccion eq 'borrar_file'
    &&
    $tipo eq 'operario'
) {

    my $file = $cgi->param('file') || '';

    if (
        $file =~ /^[a-zA-Z0-9._-]+$/
    ) {

        my $ruta =
            "$MANUALES_DIR/$file";

        if (-f $ruta) {

            if (unlink($ruta)) {

                print qq{
                <div class="card">
                ✅ Archivo eliminado.
                </div>
                };

            }
            else {

                print qq{
                <div class="card">
                ❌ Error eliminando archivo.
                </div>
                };
            }
        }
    }
}

# =========================================================
# WEB PERSONAL
# =========================================================

elsif (
    $seccion eq 'web'
    &&
    $tipo eq 'ciudadano'
) {

    print qq{

<div class="card">

<h2>🌐 Espacio Web Personal</h2>

<p>
Tu contenido está en:
<code>/home/$usuario_safe/public_html</code>
</p>

<form method="POST"
action="?seccion=eliminar_web">

<input type="hidden"
name="csrf_token"
value="$csrf_token">

<button type="submit"
class="btn-danger">

Limpiar public_html

</button>

</form>

</div>

};
}

# =========================================================
# ELIMINAR WEB
# =========================================================

elsif ($seccion eq 'eliminar_web') {

    my $token = $cgi->param('csrf_token') || '';

    if (validar_csrf($token)) {

        my $webdir =
            "/home/$usuario/public_html";

        if (-d $webdir) {

            remove_tree(
                $webdir,
                { keep_root => 1 }
            );

            print qq{
            <div class="card">
            ✅ public_html limpiado.
            </div>
            };
        }
    }
}

# =========================================================
# BAJA
# =========================================================

elsif ($seccion eq 'baja') {

    print qq{

<div class="card"
style="border:2px solid #e74c3c;">

<h2 style="color:#e74c3c;">

Eliminar Cuenta

</h2>

<p>

Esta acción eliminará:

<ul>
<li>Usuario MariaDB</li>
<li>Usuario Linux</li>
<li>Directorio HOME</li>
</ul>

</p>

<form method="POST"
action="?seccion=confirmar_baja">

<input type="hidden"
name="csrf_token"
value="$csrf_token">

<button type="submit"
class="btn-danger">

Confirmar Baja

</button>

</form>

</div>

};
}

# =========================================================
# CONFIRMAR BAJA
# =========================================================

elsif ($seccion eq 'confirmar_baja') {

    my $token = $cgi->param('csrf_token') || '';

    unless (validar_csrf($token)) {

        print qq{
        <div class="card">
        Token CSRF inválido.
        </div>
        };

    }
    else {

        # =========================
        # ELIMINAR DB
        # =========================

        my $sth =
            $dbh->prepare(
                "DELETE FROM usuarios
                 WHERE login=?"
            );

        $sth->execute($usuario);

        # =========================
        # ELIMINAR LINUX
        # =========================

        eval {

            my $passwd =
                Unix::Passwd::File->new(
                    '/etc/passwd'
                );

            my $shadow =
                Unix::Passwd::File->new(
                    '/etc/shadow'
                );

            if ($passwd->user($usuario)) {

                $passwd->delete($usuario);

                $passwd->commit();
            }

            if ($shadow->user($usuario)) {

                $shadow->delete($usuario);

                $shadow->commit();
            }
        };

        # =========================
        # BORRAR HOME
        # =========================

        my $home =
            "/home/$usuario";

        if (
            -d $home
            &&
            $usuario ne 'root'
        ) {

            remove_tree($home);
        }

        # =========================
        # CERRAR SESIÓN
        # =========================

        $session->delete();
        $session->flush();

        print qq{

<div class="card">

<h2>

Cuenta eliminada correctamente.

</h2>

<meta http-equiv="refresh"
content="3;url=/index.html">

</div>

};
    }
}

# =========================================================
# FIN HTML
# =========================================================

print qq{

</div>
</div>

</body>
</html>

};

# =========================================================
# CERRAR DB
# =========================================================

$dbh->disconnect();
