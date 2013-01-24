#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use File::Util;
use Data::Dumper;
use Getopt::Long;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use MyDB;
use utf8;
use 5.010;

my $db;
my %option = ( cache => 1, );
GetOptions( 'cache=i' => \$option{cache} );

&main();

sub main {
    my $areas = &get_areas();
    my $db    = &get_db_handle();

    my $area_href = &get_hospital();
    while ( my ( $area_name, $hospital_href ) = each %$area_href ) {
        while ( my ( $hospital_name, $hospital_url ) = each %$hospital_href ) {
            my @article_urls =
              &get_sub_list(
                &get_remote_content( $option{cache}, $hospital_url ) );
            for (@article_urls) {
                my $article = &get_remote_content( $option{cache}, $_ );

                #my ($title) = $article=~ /myCorrection\('(.*?)',/gs;
                my ($title) = $article =~ /<title>(.*?)<\/title>/gs;
                ($article) = $article =~ /id="yr-article-body">(.*?)<\/div>/gs;
                $article =~ s/<a.*?>.*?<\/a>//gs;
                for my $delete_key (
                    '本篇编辑',    '请点击',
                    '精彩推荐',    '文章来源',
                    '感谢丫友',    '相关信息',
                    '相关的信息', '更多关于',
                    '更多信息', '相关推荐',
                    '参考丫友'
                  )
                {
                    my $delete_keyword = $delete_key;
                    utf8::encode($delete_keyword);
                    $article =~ s/<p>[^p]*?$delete_keyword.*?<\/p>//gs;
                    $article =~ s/<h\d>[^h]*?$delete_keyword.*?<\/h\d>//gs;
                    #$article =~ s{<span.*?>[^<]*?$delete_keyword.*?</span>}{}gs;
                    $article =~ s{$delete_keyword.*?<}{<}gs;
                }

                my $sth = $db->prepare(
                    'replace into kcollection_shouxu(title,content,type,area_id)
                    values(?,?,1,?)'
                );
                $sth->execute( $title, $article, $areas->{$area_name} );
            }
        }
    }
}

sub get_db_handle {
    unless ($db) {
        $db = MyDB->db_conn('baby');
        $db->prepare('set names utf8')->execute();
        $db->prepare('truncate kcollection_shouxu')->execute();
    }
    return $db;
}

sub get_hospital {
    my $url = 'http://sh.iyaya.com/zhinan/yihu/';
    my $content = &get_remote_content( $option{cache}, $url );
    ($content) = $content =~ /"item_list"(.*)"item_list"/gs;
    my %hash = $content =~ /<div class="title">(.*?)<\/div>(.*?)<div/gs;
    my @hospital = ();
    while ( my ( $area, $content ) = each %hash ) {
        my @arr = $content =~ /<a href="(.*?)" title="(.*?)"/gs;
        @arr = reverse @arr;
        $hash{$area} = {@arr};
    }
    return \%hash;
}

sub get_sub_list {
    my $content = shift;
    my @content = $content =~ /<dl class="link-list zhm-yy">(.*?)<\/dl>/gs;
    pop @content;
    pop @content;
    my @list;
    for (@content) {
        my $keyword = m/<strong>(.*?)<\/strong>/gs;
        my @urls    = m/href="(.*?)"/gs;
        push @list, reverse @urls;
    }
    return @list;

}

sub get_areas {
    my $url = 'http://sh.iyaya.com/zhinan/yihu/';
    my $content = &get_remote_content( $option{cache}, $url );
    ($content) = $content =~ /"item_list"(.*)"item_list"/gs;
    my @areas = $content =~ /<div class="title">(.*?)<\/div>/gs;
    my $db = &get_db_handle();
    $db->prepare('set names utf8')->execute();
    my $sth = $db->prepare('truncate kcollection_area')->execute();
    for (@areas) {
        $sth =
          $db->prepare('insert into kcollection_area(name,pid) value (?,1)');
        $sth->execute($_);
    }
    $sth = $db->prepare('select id,name from kcollection_area where pid=1');
    $sth->execute();
    my $arr_ref = $sth->fetchall_arrayref();
    my @new_arr;
    for (@$arr_ref) {
        push @new_arr, ( $_->[0], $_->[1] );
    }
    return +{ reverse @new_arr };
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

