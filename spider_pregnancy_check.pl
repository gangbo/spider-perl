#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use File::Util;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Getopt::Long;
use utf8;
use MyDB;
use Data::Dumper;

main();

sub main {
    my $args    = get_options();
    my @urls    = ('http://www.pcbaby.com.cn/qzbd/hyshbk/yqijcqjzq/');
    my $content = get_remote_content( $args->{cache}, $urls[0] );
    my @details = filter($content);

    #    print Dumper \@details;
    my $db = MyDB->db_conn('baby');
    $db->prepare('set names utf8')->execute();
    $db->prepare('delete from kcollection_pregnancy')->execute();
    for (@details) {
        my $sth =
          $db->prepare(
'replace into kcollection_pregnancy(title,content,summary) values(?,?,?)'
          );
        my $summary = $_->[1];
        $summary =~ s/<.*?>//g;
        $sth->execute( @$_, substr( $summary, 0, 80 ) );
    }
}

sub filter {
    my $content = shift;
    my @arr     = $content =~
/<span class="lh24"><b>(.*?)<\/b><\/span>\r\n<p class="lh24">(.*?)<\/p>/sg;
    my @new_arr = ();
    my $i       = 0;
    for (@arr) {
        $_ =~ s/^[ \t\r\n\s]+//s;
        push @{ $new_arr[ int $i / 2 ] }, $_;
        $i++;
    }
    return @new_arr;
}

sub get_options {
    my %args = ( cache => 1, );
    GetOptions( 'cache=i' => \$args{cache} );
    return \%args;
}

sub get_remote_content {
    my ( $cache, $url ) = @_;
    my $cache_name = 'cache/' . md5_hex($url);
    print $cache_name;
    my $f          = File::Util->new;
    if ( $cache and $f->existent($cache_name) ) {
        print " read cache \n\n";
        return $f->load_file($cache_name);
    }
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;
    my $response = $ua->get($url);

    if ( $response->is_success ) {
        print " read remote content then write cache\n\n";
        my $content = $response->decoded_content;
        utf8::encode($content);
        $f->write_file( 'file' => $cache_name, 'content' => $content );
        return $content;
    }
    else {
        die $response->status_line;
    }
}
