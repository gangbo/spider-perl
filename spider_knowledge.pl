#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use File::Util;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Getopt::Long;
use utf8;
use URL::Encode qw/url_encode_utf8/;
use Data::Dumper;

my $query_str = {
    woyaohuaiyun => {
        mid => 2,
        keywords =>
          [ '优生优育,', '不孕不育', '孕前营养', '未准爸爸' ],
    },
    shiyuehuaitai => { mid => [ 7, 12 ] },
    fenmianxinshenger=> { mid => [ 35 ] },
};

main();

sub main {
    my $args = get_options();
    my $url = &get_url_list();
    my $all_url  = {
            1=>[],
            2=>[],
            4=>[]
    };
    #我要怀孕
    for ( @{$url->{woyaohuaiyun}}) {
       push @{$all_url->{1}},filter(get_remote_content($args->{cache},$_->{url}));
    }
    #十月怀胎
    for ( @{$url->{shiyuehuaitai}}){
       push @{$all_url->{2}},filter(get_remote_content($args->{cache},$_->{url}));
    }
    #分娩与新生儿
    for ( @{$url->{fenmianxinshenger}}){
       push @{$all_url->{4}},filter(get_remote_content($args->{cache},$_->{url}));
    }

    #    print Dumper \@details;
    my $db = MyDB->db_conn('baby');
    $db->prepare('set names utf8')->execute();
    $db->prepare('delete from kcollection_article')->execute();
    while( my ($category,$urls) = each %$all_url){
        for(@$urls){
            my $content = &filter_detail(&get_remote_content($args->{cache},'http://www.mamiai.com.cn'.$_));
            my $sth = $db->prepare('replace into kcollection_article(title,detail,cid,keyword,summary) value (?,?,?,?,?)');
            $sth->execute($content->{title},$content->{detail},$category,$content->{keyword},$content->{summary});
        }
    }
}

sub filter {
    my $content = shift;
    ($content) = $content =~ /class="yunyu_list">(.*?)<\/ul>/gs;
    my @arr     = $content =~
/<a href="([^"]*?)"/sg;
    return @arr;
}

sub filter_detail {
    my $content = shift;
    my ($title) = $content =~ /<p class="title">(.*?)<\/p>/gs;
    my ($keyword) = $content =~ /class="yunyucontent_note_bg"(.*?)<\/div>/gs;
    my @keywords = $keyword =~ /<a.*?>(.*?)<\/a>/gs;
    $keyword = join ',',@keywords;

    ($content) = $content =~ /<cite>(.*?)<\/cite>/gs;
    $content =~ s/<\/?a.*?>//gs;
    $content =~ s/<img.*?>//gs;
    my $summary = $content;
    $summary =~ s/<.*?>//gs;
    $summary = substr($summary,0,250);
    return {
        title=>$title,
        detail =>$content,
        keyword=>$keyword,
        summary=>$summary
    };
}

sub get_options {
    my %args = ( cache => 1, );
    GetOptions( 'cache=i' => \$args{cache} );
    return \%args;
}

sub get_remote_content {
    my ( $cache, $url ) = @_;
    my $cache_name = 'cache/' . md5_hex($url);
    #print $cache_name;
    my $f = File::Util->new;
    if ( $cache and $f->existent($cache_name) ) {
        #    print " read cache \n\n";
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

sub get_url_list {
    my $base_url =
      'http://www.mamiai.com.cn/mamiai/handler/Pregnant-ArticleList?';
    my @woyaohuaiyun_urls = ();
    for ( @{ $query_str->{woyaohuaiyun}->{keywords} } ) {
        push @woyaohuaiyun_urls, {
            keyword => $_,
            url     => $base_url
              . 'keyword='
              . url_encode_utf8("$_,$_") . '&mid='
              . $query_str->{woyaohuaiyun}->{mid}
        };
    }
    my $url->{woyaohuaiyun} = \@woyaohuaiyun_urls;
    my @shiyuehuaitai_urls = ();
    for ( @{ $query_str->{shiyuehuaitai}->{mid} } ) {
        push @shiyuehuaitai_urls, { url => $base_url . "mid=$_" };
    }
    $url->{shiyuehuaitai} = \@shiyuehuaitai_urls;
    my @fenmianxinshenger=();
    for ( @{ $query_str->{fenmianxinshenger}->{mid} } ) {
        push @fenmianxinshenger, { url => $base_url . "mid=$_" };
    }
    $url->{fenmianxinshenger} = \@fenmianxinshenger;
    return $url;
}
