#!/usr/bin/perl

use strict;
use warnings;

use CGI::Cookie;
use CGI::Session;


require "/usr/lib/cgi-bin/conexion.pl";

my $cgi = CGI->new;

my $cgi = CGI->new;

print $cgi->header(
    -type    => 'text/html',
    -charset => 'UTF-8'
);

# =========================================================
# 2. PARÁMETROS
# =========================================================

html',
        -charset => 'UTF-8'
    );

    print "<h2>Error</h2>";
    print "<p>Debe completar todos los campos.</p>";

    exit;
}

# =========================================================
# 3. CONEXIÓN DB
# =========================================================

my $dbh = conexion::conectar();

# =========================================================
# 4. VERIFICAR PASSWORD EN BASE DE DATOS
# =========================================================

my $sql = q{
    SELECT password, saltHash
    FROM usuarios
    WHERE login = ?
};

my $sth = $dbh->prepare($sql);

$sth->execute($usuario_sesion);

my ($hash_db, $salt_db) = $sth->fetchrow_array();

if (!$hash_db) {

    print $cgi->header(
        -type    => 'text/html',
        -charset => 'UTF-8'
    );

    print "<h2>Error</h2>";
    print "<p>Usuario no encontrado.</p>";

    exit;
}

my $hash_actual = sha256_hex($old_password . $salt_db);

if ($hash_actual ne $hash_db) {

    print $cgi->header(
        -type    => 'text/html',
        -charset => 'UTF-8'
    );

    print "<h2>Error</h2>";
    print "<p>La contraseña actual es incorrecta.</p>";

    exit;
}

# =========================================================
# 5. VERIFICAR PASSWORD DEL SISTEMA LINUX
# =========================================================

my $auth = Authen::Simple::Passwd->new();

unless ($auth->authenticate($usuario_sesion, $old_password)) {

    print $cgi->header(
        -type    => 'text/html',
        -charset => 'UTF-8'
    );

    print "<h2>Error</h2>";
    print "<p>La contraseña del sistema Linux no coincide.</p>";

    exit;
}

# =========================================================
# 6. GENERAR NUEVO HASH DB
# =========================================================

my $nuevo_salt = int(rand(1000000));

my $nuevo_hash = sha256_hex($new_password . $nuevo_salt);

# =========================================================
# 7. ACTUALIZAR BASE DE DATOS
# =========================================================

my $sql_update = q{
    UPDATE usuarios
    SET password = ?, saltHash = ?
    WHERE login = ?
};

my $sth_update = $dbh->prepare($sql_update);

$sth_update->execute(
    $nuevo_hash,
    $nuevo_salt,
    $usuario_sesion
);

# =========================================================
# 8. ACTUALIZAR /etc/shadow
# =========================================================

my $shadow = Unix::Passwd::File->new(
    passwd => "/etc/passwd",
    shadow => "/etc/shadow"
);

unless ($shadow) {

    print $cgi->header(
        -type    => 'text/html',
        -charset => 'UTF-8'
    );

    print "<h2>Error</h2>";
    print "<p>No se pudo acceder a /etc/shadow.</p>";

    exit;
}

# Generar hash estilo Linux SHA512
my $salt_linux = '$6$' . int(rand(99999999));

my $linux_hash = crypt($new_password, $salt_linux);

# Obtener entrada actual
my $user = $shadow->user($usuario_sesion);

unless ($user) {

    print $cgi->header(
        -type    => 'text/html',
        -charset => 'UTF-8'
    );

    print "<h2>Error</h2>";
    print "<p>Usuario inexistente en el sistema Linux.</p>";

    exit;
}

# Cambiar password hash
$user->passwd($linux_hash);

# Guardar cambios
$shadow->save();

# =========================================================
# 9. RESPUESTA FINAL
# =========================================================

print $cgi->header(
    -type    => 'text/html',
    -charset => 'UTF-8'
);

print qq{
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Password actualizada</title>

<style>
body{
    background:#1f2a33;
    color:white;
    font-family:Arial;
    padding:40px;
}

.box{
    background:#24333e;
    padding:30px;
    border-radius:10px;
    max-width:600px;
    margin:auto;
}

a{
    color:#1ab188;
}
</style>

</head>
<body>

<div class="box">

<h2>Contraseña actualizada correctamente</h2>

<p>
La contraseña fue modificada:
</p>

<ul>
    <li>Base de datos</li>
    <li>Sistema Linux (/etc/shadow)</li>
</ul>

<p>
<a href="paginaPrin.pl">
Volver al panel
</a>
</p>

</div>

</body>
</html>
};

$dbh->disconnect();

exit;
