#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use Digest::SHA qw(sha256_hex);
use File::Path qw(make_path);
#use File::chmod;
#use Unix::Passwd::File;
use File::Copy qw(copy);
use Linux::usermod;
use Crypt::PasswdMD5 qw(unix_md5_crypt);

require "/usr/lib/cgi-bin/conexion.pl";

# =========================================================
# CGI
# =========================================================

my $cgi = CGI->new;

print $cgi->header(
    -type    => 'text/html',
    -charset => 'UTF-8'
);

# =========================================================
# PARÁMETROS
# =========================================================

my $login     = $cgi->param('login')     || '';
my $nombre    = $cgi->param('nombre')    || '';
my $email     = $cgi->param('email')     || '';
my $direccion = $cgi->param('direccion') || '';
my $password  = $cgi->param('password')  || '';

# =========================================================
# LIMPIEZA BÁSICA
# =========================================================

$login     =~ s/^\s+|\s+$//g;
$nombre    =~ s/^\s+|\s+$//g;
$email    =~ s/^\s+|\s+$//g;
$direccion =~ s/^\s+|\s+$//g;

# =========================================================
# VALIDACIONES
# =========================================================

my @errores;

# Usuario Linux válido
unless (
    $login =~ /^[a-z_][a-z0-9_-]{2,31}$/
) {
    push @errores,
        "Login inválido.";
}

# Nombre básico
unless (
    length($nombre) >= 3
) {
    push @errores,
        "Nombre demasiado corto.";
}

# Email válido
unless (
    $email =~ /^[A-Za-z0-9._%+-]+\@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
) {
    push @errores,
        "Correo inválido.";
}

# Password fuerte mínima
unless (
    length($password) >= 8
) {
    push @errores,
        "La contraseña debe tener al menos 8 caracteres.";
}

# Dirección mínima
unless (
    length($direccion) >= 5
) {
    push @errores,
        "Dirección inválida.";
}

# Usuarios reservados
my %usuarios_reservados = map {
    $_ => 1
} qw(
    root
    daemon
    bin
    sys
    sync
    games
    man
    lp
    mail
    nobody
    www-data
    mysql
);

if ($usuarios_reservados{$login}) {

    push @errores,
        "Nombre de usuario reservado.";
}

# =========================================================
# MOSTRAR ERRORES
# =========================================================

if (@errores) {

    print qq{
    <h2>Error en el registro</h2>
    <ul>
    };

    foreach my $e (@errores) {

        my $safe = escapeHTML($e);

        print qq{
        <li>$safe</li>
        };
    }

    print qq{
    </ul>
    };

    exit;
}

# =========================================================
# ESCAPAR HTML
# =========================================================

my $login_safe  = escapeHTML($login);
my $nombre_safe = escapeHTML($nombre);

# =========================================================
# TIPO DE USUARIO
# =========================================================

my $tipo_usuario = 'ciudadano';

my $shell_linux = '/usr/sbin/nologin';

if (
    $email =~ /\@ecosalmantica\.es$/i
) {

    $tipo_usuario = 'operario';

    $shell_linux = '/bin/bash';
}

# =========================================================
# HASH WEB
# =========================================================

my $salt_web = int(rand(999999));

my $hash_web =
    sha256_hex(
        $password . $salt_web
    );

# =========================================================
# HASH LINUX
# =========================================================

my $linux_salt =
    substr(time(), -8);

my $linux_hash =
    unix_md5_crypt(
        $password,
        $linux_salt
    );

# =========================================================
# DB
# =========================================================

my $dbh = conexion::conectar();

# =========================================================
# COMPROBAR USUARIO EXISTENTE
# =========================================================

my $check = $dbh->prepare(
    "SELECT login
     FROM usuarios
     WHERE login = ?
        OR email = ?"
);

$check->execute(
    $login,
    $email
);

if ($check->fetchrow_array()) {

    print qq{
    <h2>Error</h2>
    <p>
    El usuario o correo ya existen.
    </p>
    };

    exit;
}

# =========================================================
# INSERTAR DB
# =========================================================

my $sql = q{

INSERT INTO usuarios
(
    login,
    nombre,
    email,
    password,
    saltHash,
    direccion,
    tipo,
    activo
)
VALUES
(
    ?, ?, ?, ?, ?, ?, ?, 0
)

};

my $sth = $dbh->prepare($sql);

eval {

    $sth->execute(
        $login,
        $nombre,
        $email,
        $hash_web,
        $salt_web,
        $direccion,
        $tipo_usuario
    );
};

if ($@) {

    print qq{
    <h2>Error DB</h2>
    <p>
    Error insertando usuario.
    </p>
    };

    exit;
}

# =========================================================
# CREAR USUARIO LINUX
# =========================================================

eval {

    # =====================================================
    # COMPROBAR SI YA EXISTE
    # =====================================================

    if (getpwnam($login)) {

        die "El usuario Linux ya existe";
    }

    # =====================================================
    # HOME
    # =====================================================

    my $home = "/home/$login";

    # =====================================================
    # GID
    # =====================================================

    my $gid_sistema =
        ($tipo_usuario eq 'operario')
        ? 1002
        : 1001;

    # =====================================================
    # CREAR USUARIO
    # =====================================================

    my $ok = Linux::usermod->add(
        $login,          # usuario
        $password,       # password
        $nombre,         # gecos
        $gid_sistema,    # gid
        '',              # extra
        $home,           # home
        $shell_linux     # shell
    );

    die "Error creando usuario Linux"
        unless $ok;

    # =====================================================
    # OBTENER USUARIO
    # =====================================================

    my $user = Linux::usermod->new($login);

    die "No se pudo obtener usuario Linux"
        unless $user;

    my $uid = $user->get('uid');
    my $gid = $user->get('gid');

    # =====================================================
    # CREAR HOME
    # =====================================================

    unless (-d $home) {

        mkdir($home)
            or die "No se pudo crear home: $!";
    }

    chmod(0755, $home);

    chown($uid, $gid, $home);

    # =====================================================
    # COPIAR SKEL
    # =====================================================

    use File::Copy qw(copy);

    copy(
        "/etc/skel/.bash_logout",
        "$home/.bash_logout"
    );

    copy(
        "/etc/skel/.bashrc",
        "$home/.bashrc"
    );

    copy(
        "/etc/skel/.profile",
        "$home/.profile"
    );

    chown(
        $uid,
        $gid,
        "$home/.bash_logout",
        "$home/.bashrc",
        "$home/.profile"
    );

    # =====================================================
    # PUBLIC_HTML
    # =====================================================

    my $public =
        "$home/public_html";

    unless (-d $public) {

        mkdir($public)
            or die "No se pudo crear public_html";
    }

    chmod(0755, $public);

    chown($uid, $gid, $public);

    # =====================================================
    # BLOG
    # =====================================================

    my $blog =
        "$home/blog";

    unless (-d $blog) {

        mkdir($blog)
            or die "No se pudo crear blog";
    }

    chmod(0755, $blog);

    chown($uid, $gid, $blog);
};
# =========================================================
# RESPUESTA
# =========================================================

print qq{

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Registro completado</title>

<style>

body{
    background:#13232f;
    color:white;
    font-family:Arial,sans-serif;
    padding:40px;
}

.card{
    background:#24333e;
    padding:30px;
    border-radius:10px;
    max-width:600px;
    margin:auto;
}

.success{
    color:#1ab188;
}

code{
    background:#000;
    padding:4px;
}

a{
    color:#4eb5f1;
}

</style>

</head>

<body>

<div class="card">

<h2 class="success">

Registro completado

</h2>

<p>

Usuario
<b>$login_safe</b>
creado correctamente.

</p>

<p>

Tipo:
<b>$tipo_usuario</b>

</p>

<p>

Home:
<code>/home/$login_safe</code>

</p>

<p>

Shell:
<code>$shell_linux</code>

</p>

<br>

<a href="/index.html">

Volver al login

</a>

</div>

</body>

</html>

};

# =========================================================
# CERRAR DB
# =========================================================

$dbh->disconnect();
