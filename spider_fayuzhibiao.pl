#!/usr/bin/perl
use strict;
use warnings;
use File::Util;
use Data::Dumper;
use MyDB;
use utf8;

open( my $fh, "<", "fayuzhibiao.txt" );
my @arr;
while (<$fh>) {
    @arr = /<tr>.*?<\/tr>/g;

    #print Dumper \@arr[1..22];
}
@arr = @arr[ 1 .. 24 ];
my @new_arr;
my $i = 0;
for (@arr) {
    $_ =~ s/<.*?>/#/g;
    my @column = split /#+/, $_;
    print @column;
    print "\n\n";
    print Dumper @column;
    my $new_string = '';
    if ( scalar @column > 3 ) {
        $new_string .= "<h3>$column[2]:</h3><br/>$column[3]<br/>";
    }
    else {
        $new_string .= "<h3>$column[1]:</h3><br/>$column[2]<br/>";
    }
    @new_arr[ int $i / 2 ] .= $new_string;
    $i++;
}
my $db = MyDB->db_conn('baby');
$db->prepare('set names utf8')->execute();

my $month = 1;
for (@new_arr) {
    my $sth = $db->prepare(
        'replace into kcollection_grow(month,type,detail) values(?,?,?)');
    $sth->execute( $month++, 'after', $_ );
}
