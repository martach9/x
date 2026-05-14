#!/usr/bin/perl

# Script que permite dar de alta un usuario.

# Author: Víctor Parra [parra@usal.es]

# AVISO: Requiere permisos de root
# Es necesrio instalar el File::Copy y el Linux::usermod
# ># perl -MCPAN -e 'install File::Copy::Recursive'
# ># perl -MCPAN -e 'install Linux::usermod'

# Parámetros:
# - [nombre_del_usuario] -> Nombre del nuevo usuario
# - [password]  -> Contraseña del nuevo usuario

$args=@ARGV;

if ($args < 2)
{
 print "\n";
 print "Uso: $0 [nombre_del_usuario] [password]\n";
 print "\n";
 print "\n";
 die "Abortando";
}

$ruta="/home/" . $ARGV[0] . "/";

$usuario=$ARGV[0];
use Linux::usermod;
use File::Copy;

print "La ruta /home es: $ruta \n";

my $pass=$ARGV[1];

mkdir $ruta;
chmod(0770, $ruta) || print $!;

Linux::usermod->add($usuario,$pass,'',100,'',$ruta,"/bin/bash") || print "USERADD: $! \n";
$user=Linux::usermod->new($usuario);
chown($user->get(uid), $user->get(gid), $ruta) || print "CHOWN USER: $! \n";

copy("/etc/skel/.bash_logout", $ruta . ".bash_logout");
copy("/etc/skel/.bashrc", $ruta . ".bashrc");
copy("/etc/skel/.profile", $ruta . ".profile");

$subruta = $ruta . "/" . "public_html";
mkdir $subruta;
chown($user->get(uid), $user->get(gid), $subruta) || print "CHOWN: $! \n";

`setquota -u $usuario 0 5120 0 0 -a $ruta`;

print "\nUsuario $usuario creado con éxito\n";
print "\n";
exit;
