#!/usr/bin/perl

use strict;
use warnings;

use Archive::Tar;
use POSIX qw(strftime);
use Path::Tiny;
use Log::Log4perl;
use JSON;
use Cwd qw(getcwd);
use File::Find qw(find);

require "/var/www/cgi-bin/conexion.pl";

# =========================
# CONFIGURACION
# =========================

my $BACKUP_DIR = "/backups";

my @DIRECTORIOS = (
    '/etc',
    '/home',
    '/var/www',
    '/var/mail'
);

my @USUARIOS = (
    '/etc/passwd',
    '/etc/shadow',
    '/etc/group',
    '/etc/gshadow'
);

my $LOG_SSH = "/var/log/auth.log";

# Nombres de dias en  para el fichero de backup.
# El fichero del lunes siempre se llama system_lunes.tar.gz,
# sobreescribiendo al del lunes de la semana anterior.
# Asi el espacio en disco es fijo: exactamente 7 ficheros.
my @DIAS = qw(domingo lunes martes miercoles jueves viernes sabado);

# =========================
# LOGGER
# =========================

Log::Log4perl->easy_init(
{
    level  => 'INFO',
    file   => ">>/var/log/disaster_recovery.log",
    layout => '%d %p %m%n'
});

my $logger = Log::Log4perl->get_logger();

# =========================
# BACKUP SISTEMA
# =========================

sub backup_sistema {

    path($BACKUP_DIR)->mkpath;

    # Nombre del fichero segun el dia de la semana (0=domingo..6=sabado).
    # Cada semana sobreescribe al de la semana anterior.
    my $dia_num  = (localtime)[6];
    my $dia_nombre = $DIAS[$dia_num];
    my $archivo  = "$BACKUP_DIR/system_$dia_nombre.tar.gz";

    $logger->info("Iniciando backup del $dia_nombre -> $archivo");

    # Recopilar rutas absolutas antes de cambiar de directorio.
    my @absolutos = grep { -e $_ } (@DIRECTORIOS, @USUARIOS);

    if (!@absolutos) {
        $logger->warn("No se encontraron rutas para el backup");
        print "Advertencia: ninguna ruta encontrada para el backup\n";
        return;
    }

    my @ficheros_absolutos;

    find(
        {
            wanted => sub {
                push @ficheros_absolutos, $File::Find::name
                    if -f $File::Find::name || -d $File::Find::name;
            },
            no_chdir => 1,
        },
        @absolutos
    );

    # Convertir rutas absolutas en relativas quitando la / inicial.
    my @ficheros_relativos = map { (my $r = $_) =~ s{^/+}{}; $r }
                             grep { $_ ne '/' }
                             @ficheros_absolutos;

    if (!@ficheros_relativos) {
        $logger->warn("No se encontraron ficheros para el backup");
        print "Advertencia: ningun fichero encontrado para el backup\n";
        return;
    }

    # chdir a / y añadir ficheros con rutas relativas.
    # Si ya existe el fichero de este dia, se sobreescribe automaticamente.
    my $cwd = getcwd();
    chdir '/' or die "No se puede hacer chdir a /: $!";

    my $tar = Archive::Tar->new;
    $tar->add_files(@ficheros_relativos);
    $tar->write($archivo, COMPRESS_GZIP);

    chdir $cwd or die "No se puede volver a $cwd: $!";

    $logger->info(
        "Backup sistema completado: $archivo ("
        . scalar(@ficheros_relativos)
        . " entradas)"
    );

    print "Backup del $dia_nombre creado: $archivo ("
        . scalar(@ficheros_relativos)
        . " ficheros)\n";
}

# =========================
# BACKUP MYSQL
# =========================

sub backup_mysql {

    my $dbh = conexion::conectar();

    # Volcado completo de todas las tablas de la base de datos.
    # Nombre del fichero igual que el sistema: por dia de la semana.
    my $dia_num    = (localtime)[6];
    my $dia_nombre = $DIAS[$dia_num];
    my $archivo    = "$BACKUP_DIR/mysql_$dia_nombre.json";

    # Obtenemos todas las tablas de la base de datos actual
    my $sth_tablas = $dbh->prepare("SHOW TABLES");
    $sth_tablas->execute();
    my @tablas = map { $_->[0] } @{ $sth_tablas->fetchall_arrayref() };
    $sth_tablas->finish();

    my %volcado;

    foreach my $tabla (@tablas) {

        my $sth = $dbh->prepare("SELECT * FROM `$tabla`");
        $sth->execute();
        $volcado{$tabla} = $sth->fetchall_arrayref({});
        $sth->finish();

        $logger->info("Tabla volcada: $tabla ("
            . scalar(@{ $volcado{$tabla} })
            . " filas)");
    }

    open(my $fh, '>', $archivo)
        or die "No se puede crear $archivo: $!";

    print $fh encode_json(\%volcado);

    close($fh);
    $dbh->disconnect();

    $logger->info("Backup MySQL completado: $archivo ("
        . scalar(@tablas) . " tablas)");

    print "Backup MySQL del $dia_nombre creado: $archivo\n";
}

# =========================
# ANALISIS LOG SSH
# =========================

sub analizar_logs {

    open(my $fh, '<', $LOG_SSH)
        or die "No se puede abrir $LOG_SSH: $!";

    while (my $linea = <$fh>) {

        if ($linea =~ /Failed password.*from ([0-9\.]+)/) {

            my $ip = $1;
            $logger->info("LOGIN FALLIDO desde $ip");
        }

        elsif ($linea =~ /Accepted password.*from ([0-9\.]+)/) {

            my $ip = $1;
            $logger->info("LOGIN CORRECTO desde $ip");
        }
    }

    close($fh);
}

# =========================
# RESTAURACION
# =========================

sub restaurar {

    my ($archivo) = @_;

    die "Indica backup\n"                  unless $archivo;
    die "El archivo no existe: $archivo\n" unless -f $archivo;

    my $tmpdir = "/tmp/restore_$$";
    path($tmpdir)->mkpath;

    my $cwd = getcwd();
    chdir $tmpdir or die "No se puede hacer chdir a $tmpdir: $!";

    my $tar = Archive::Tar->new;
    $tar->read($archivo, 1);
    $tar->extract()
        or $logger->warn("Algunos ficheros no se pudieron extraer: "
            . $tar->error);

    chdir $cwd or die "No se puede volver a $cwd: $!";

    $logger->info("Restauracion completada en $tmpdir");

    print "Sistema restaurado en: $tmpdir\n";
    print "\n";
    print "IMPORTANTE: revisa el contenido antes de copiarlo al sistema:\n";
    print "  ls -la $tmpdir/\n";
    print "\n";
    print "Para aplicar al sistema (como root):\n";
    print "  cp -a $tmpdir/etc/   /etc/\n";
    print "  cp -a $tmpdir/home/  /home/\n";
    print "  cp -a $tmpdir/var/   /var/\n";
}

# =========================
# ESTADO DE LOS BACKUPS
# =========================

sub estado_backups {

    print "\nEstado actual de backups en $BACKUP_DIR:\n";
    print "-" x 55 . "\n";

    foreach my $dia (@DIAS) {

        my $arch_sys = "$BACKUP_DIR/system_$dia.tar.gz";
        my $arch_sql = "$BACKUP_DIR/mysql_$dia.json";

        if (-f $arch_sys) {
            my $bytes = -s $arch_sys;
            my $tam   = int($bytes / 1024 / 1024 * 10) / 10;
            my $fecha = strftime(
                "%Y-%m-%d %H:%M",
                localtime((stat($arch_sys))[9])
            );
            printf "  %-10s  sistema: %5.1f MB  (%s)\n",
                $dia, $tam, $fecha;
        }
        else {
            printf "  %-10s  sistema: PENDIENTE\n", $dia;
        }

        if (-f $arch_sql) {
            my $bytes = -s $arch_sql;
            my $tam   = int($bytes / 1024);
            printf "  %-10s  mysql:   %s KB\n", "", $tam;
        }
        else {
            printf "  %-10s  mysql:   PENDIENTE\n", "";
        }
    }

    print "-" x 55 . "\n";
}

# =========================
# MAIN
# =========================

my $accion = shift || '';

if ($accion eq 'backup') {

    backup_sistema();
    backup_mysql();
    analizar_logs();
}

elsif ($accion eq 'restore') {

    my $archivo = shift;
    restaurar($archivo);
}

elsif ($accion eq 'estado') {

    estado_backups();
}

else {

    print "Uso:\n";
    print "  perl copiaSec.pl backup\n";
    print "  perl copiaSec.pl restore /backups/system_lunes.tar.gz\n";
    print "  perl copiaSec.pl estado\n";
    print "\nBackups disponibles (system_DIA.tar.gz / mysql_DIA.json):\n";
    print "  " . join(", ", @DIAS) . "\n";
}
