#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use File::Util;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Data::Dumper;
use Getopt::Long;
use utf8;
use MyDB;

main();

sub main {
    my $args = get_options();
    my @urls = (
        'http://www.pcbaby.com.cn/qzbd/hyjbbk/1008/955419.html',    #1
        'http://www.pcbaby.com.cn/qzbd/hyjbbk/1008/955420.html',    #2
        'http://www.pcbaby.com.cn/qzbd/hyjbbk/1008/955422.html',    #3
        'http://www.pcbaby.com.cn/qzbd/hyjbbk/1008/955427.html',    #4
        'http://www.pcbaby.com.cn/qzbd/hyjbbk/1008/955462.html',    #5
        'http://www.pcbaby.com.cn/qzbd/hyjbbk/1008/955464.html',    #6
        'http://www.pcbaby.com.cn/qzbd/hyjbbk/1008/955469.html',    #7
        'http://www.pcbaby.com.cn/qzbd/hyjbbk/1008/955474.html',    #8
        'http://www.pcbaby.com.cn/qzbd/hyjbbk/1008/955477.html',    #9
        'http://www.pcbaby.com.cn/qzbd/hyjbbk/1008/955478.html',    #10
    );
    my @details = ();
    for (@urls) {
        my $content = get_remote_content( $args->{cache}, $_ );
        push @details, [ filter($content) ];
    }

    #print Dumper \@details;
    my $db = MyDB->db_conn('baby');
    $db->prepare('set names utf8')->execute();
    for (@details) {
        my $sth = $db->prepare(
            'replace into kcollection_grow(month,detail,type) values(?,?,?)');
        $sth->execute( @$_, 'pre' );
    }
}

sub filter {
    my $content = shift;
    my $title;
    if ( $content =~
/<title>(.*?)<\/title>.*?text f14">(.*?)<\/div>\r\n<div class="xgKnow">/sg
      )
    {
        $title   = $1;
        $content = $2;
    }
    print $title. "====\n\n";
    if ( $title =~ /(\d{1,2})/ ) {
        print Dumper $1;
    }
    my $month = $1;
    $content =~ s/<div.*?>/<div>/g;
    $content =~ /<div>(.*)<\/div>/sg;
    $content = $1;
    $content =~ s/<div>.*?<\/div>//g;
    $content =~ s/<a.*?>/<a>/sg;
    return ( $month, $content );
}

sub get_options {
    my %args = ( cache => 1, );
    GetOptions( 'cache=i' => \$args{cache} );
    return \%args;
}

sub get_remote_content {
    my ( $cache, $url ) = @_;
    my $cache_name = 'cache/' . md5_hex($url);
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
