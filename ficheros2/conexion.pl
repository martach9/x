package conexion;

use strict;
use warnings;

use DBI;

# =========================================================
# CONFIGURACIÓN DB
# =========================================================

my $DATABASE = 'ecosalmantica';

my $HOST = 'localhost';

my $PORT = 3306;

my $USER = 'ecoadmin';

my $PASSWORD = 'Admin';

# =========================================================
# CONEXIÓN
# =========================================================

sub conectar {

    my $dsn = join(
        '',
        'DBI:mysql:',
        "database=$DATABASE;",
        "host=$HOST;",
        "port=$PORT;",
        'mysql_enable_utf8mb4=1'
    );

    my $dbh = DBI->connect(

        $dsn,

        $USER,

        $PASSWORD,

        {

            RaiseError => 1,

            PrintError => 0,

            AutoCommit => 1,

            mysql_enable_utf8mb4 => 1,

            mysql_auto_reconnect => 1
        }

    ) or die "Error conectando a MariaDB";

    # =====================================================
    # UTF8 REAL
    # =====================================================

    $dbh->do(
        q{
        SET NAMES utf8mb4
        }
    );

    $dbh->do(
        q{
        SET CHARACTER SET utf8mb4
        }
    );

    $dbh->do(
        q{
        SET SESSION collation_connection =
        'utf8mb4_unicode_ci'
        }
    );

    return $dbh;
}

# =========================================================
# CERRAR CONEXIÓN
# =========================================================

sub desconectar {

    my ($dbh) = @_;

    if (
        defined $dbh
        &&
        $dbh->ping
    ) {

        $dbh->disconnect();
    }
}

1;
