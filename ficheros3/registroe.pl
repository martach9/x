#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard escapeHTML);
use Digest::SHA qw(sha256_hex);
use Email::Sender::Simple qw(sendmail);
use Email::Simple;
use Email::Simple::Creator;

require "/var/www/cgi-bin/conexion.pl";

# =========================================================
# CGI
# =========================================================

my $cgi = CGI->new;

print $cgi->header(
    -type    => 'text/html',
    -charset => 'UTF-8'
);

# =========================================================
# PARAMETROS
# =========================================================

my $login     = $cgi->param('login')     || '';
my $nombre    = $cgi->param('nombre')    || '';
my $email     = $cgi->param('email')     || '';
my $direccion = $cgi->param('direccion') || '';

# =========================================================
# LIMPIEZA
# =========================================================

for ($login, $nombre, $email, $direccion) {
    s/^\s+|\s+$//g if defined $_;
}

# =========================================================
# VALIDACIONES
# =========================================================

my @errores;

push @errores, "Login inválido"
    unless $login =~ /^[a-z_][a-z0-9_-]{2,31}$/;

push @errores, "Nombre demasiado corto"
    unless length($nombre) >= 3;

push @errores, "Dirección inválida"
    unless length($direccion) >= 5;

push @errores, "Email no permitido"
    unless $email =~ /^[A-Za-z0-9._%+-]+\@(usal\.es|hotmail\.com|gmail\.com)$/i;

my %reservados = map { $_ => 1 } qw(
    root daemon bin sys sync games man lp mail nobody www-data mysql
);

push @errores, "Usuario reservado"
    if $reservados{$login};

# Ya existe como usuario Linux
push @errores, "Usuario ya existe en el sistema"
    if getpwnam($login);

if (@errores) {

    print "<h2>Errores</h2><ul>";
    print "<li>" . escapeHTML($_) . "</li>" for @errores;
    print "</ul>";
    exit;
}

# =========================================================
# BD
# =========================================================

my $dbh = conexion::conectar();

# =========================================================
# DUPLICADOS
# =========================================================

my $check = $dbh->prepare(q{
    SELECT login
    FROM usuarios
    WHERE login = ?
       OR email = ?
});

$check->execute($login, $email);

if ($check->fetchrow_array) {

    print "<h2>Usuario o email ya existe</h2>";
    exit;
}

# =========================================================
# TIPO USUARIO
# =========================================================

my $tipo = ($email =~ /\@usal\.es$/i)
    ? 'operario'
    : 'ciudadano';

# =========================================================
# TOKEN
# =========================================================

my $token = sha256_hex(rand() . time() . $email);

# =========================================================
# INSERT
# =========================================================

my $sql = q{
INSERT INTO usuarios
(
    login,
    nombre,
    email,
    direccion,
    tipo,
    activo,
    procesado,
    token,
    fecha_token
)
VALUES
(
    ?, ?, ?, ?, ?, 0, 0, ?, NOW()
)
};

my $sth = $dbh->prepare($sql);

$sth->execute(
    $login,
    $nombre,
    $email,
    $direccion,
    $tipo,
    $token
);

# =========================================================
# EMAIL
# =========================================================

my $link =
"https://192.168.56.107/cgi-bin/activacion.pl?token=$token";

my $email_obj = Email::Simple->create(
    header => [
        To      => $email,
        From    => 'noreply@ecosalmantica.es',
        Subject => 'Activación de cuenta'
    ],
    body => "Hola $nombre\n\nActiva tu cuenta aquí:\n$link\n"
);

sendmail($email_obj);

# =========================================================
# RESPUESTA
# =========================================================

print qq{
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Registro correcto</title>

<style>
body{
    margin:0;
    font-family:'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background:
        linear-gradient(
            135deg,
            rgba(13,31,20,0.93) 0%,
            rgba(0,168,88,0.72) 100%
        ),
        url('https://images.unsplash.com/photo-1480714378408-67cf0d13bc1b?w=1600&q=80')
        center/cover no-repeat fixed;
    display:flex;
    justify-content:center;
    align-items:center;
    min-height:100vh;
    color:white;
}

.card{
    background:#1c2b36;
    padding:40px;
    border-radius:10px;
    box-shadow:0 10px 25px rgba(0,0,0,0.5);
    width:100%;
    max-width:500px;
    text-align:center;
}

.ok{
    color:#1ab188;
    font-size:2em;
    margin-bottom:20px;
}

p{
    color:#d8e6e2;
    font-size:1.05em;
    line-height:1.6;
}

a{
    display:block;
    margin-top:30px;
    padding:15px;
    background:#1ab188;
    color:white;
    text-decoration:none;
    font-size:1.1em;
    font-weight:bold;
    border-radius:4px;
    transition:0.3s;
}

a:hover{
    background:#17a07b;
}
</style>
</head>

<body>

<div class="card">

<h2 class="ok">Registro correcto</h2>

<p>
Revisa tu correo electrónico para activar tu cuenta.
</p>

<p>
Una vez activada, podrás establecer tu contraseña e iniciar sesión.
</p>

<a href="/index.html">
Volver al login
</a>

</div>

</body>
</html>
};

$dbh->disconnect();
