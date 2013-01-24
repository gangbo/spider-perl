package MyDB;
use DBI;

sub db_conn {
    my $pkg = shift;
    my $dbname = shift;
    my $host = 'localhost';
    my $port = '3306';
    my $dsn = "DBI:mysql:$dbname:$host:$port";
    DBI->connect($dsn,'root','111111');
}

1;
