#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use File::Util;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Getopt::Long;

use Data::Dumper;

&main();

sub main {
    my $args = get_options();
    my $content = get_remote_content( $args->{cache}, $args->{url});
    my @images = $content=~ m{<img class="BDE_Image" src="(.*?)"}gs;
    print Dumper @images;
    for(@images){
        `wget $_`;
    }
}
sub get_options {
    my %args = ( cache => 1, );
    GetOptions(
        'cache=i' => \$args{cache},
        'url=s'     => \$args{url}
    );
    return \%args;
}

sub get_remote_content {
    my ( $cache, $url ) = @_;
    my $cache_name = 'cache/' . md5_hex($url);
    print $cache_name;
    my $f = File::Util->new;
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

