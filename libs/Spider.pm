package Spider;
use strict;
use warnings;
use LWP::UserAgent;
use File::Util;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Getopt::Long;
use MyDB;
use Data::Dumper;
use constant { CACHE_DIR => 'cache' };

sub new {
    my ( $pkg, $url, $method, $form, $iscache ) = @_;
    $iscache = defined $iscache ? $iscache : 1;
    bless {
        url     => $url,
        iscache => $iscache,
        method  => $method,
        form    => $form
    }, $pkg;
}

sub fetch_page {
    my $self = shift @_;

    #print "fetch_page ";
    my $fh = File::Util->new;
    my $page_content;
    if ( $self->{iscache} ) {
        $page_content = $self->load_cached_file;
        print "read cache\n";
        return $page_content if defined $page_content;
    }

    my $ua = LWP::UserAgent->new;
    $ua->timeout(5);
    $ua->env_proxy;
    my $response;
    for ( 1 .. 3 ) {
        print "---spider--url=".$self->{url}."\n";
        if ( $self->{method} && $self->{method} eq 'post' ) {
            $response = $ua->post( $self->{url}, $self->{form} );
        }
        else {
            $response = $ua->get( $self->{url} );
        }
        if ( $response->is_success ) {
            print " read remote page and write cache\n\n";
            $page_content = $response->decoded_content;
            utf8::encode($page_content);
            $self->_write_cache($page_content);
            return $page_content;
        }
        else {
            print $response->status_line;
        }
    }
}

sub _is_page_cached {
    my $self      = shift @_;
    my $is_cached = File::Util->new()->existent( $self->url_to_local_path );
    return $is_cached;
}

sub load_cached_file {
    my $self = shift @_;
    if ( $self->_is_page_cached() ) {
        my $fh = File::Util->new;
        return $fh->load_file( $self->url_to_local_path );
    }
    return;
}

sub url_to_local_path {
    my $self             = shift @_;
    my $cached_file_path = CACHE_DIR . '/' . md5_hex( $self->{url} );
    return $cached_file_path;
}

sub _write_cache {
    my ( $self, $page_content ) = @_;
    my $fh = File::Util->new;
    $fh->write_file(
        'file'    => $self->url_to_local_path,
        'content' => $page_content
    );
}

1;
