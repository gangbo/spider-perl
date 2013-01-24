#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use File::Util;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Getopt::Long;
use Template;
use Template::Constants qw( :debug );
use FindBin;
use lib "$FindBin::Bin/libs";
use Spider;
use JSON;
use MyDB;

use Data::Dumper;

my $config = {
    INCLUDE_PATH => './tpl/',    # or list ref
    INTERPOLATE  => 1,           # expand "$var" in plain text
    POST_CHOMP   => 1,           # cleanup whitespace
         #    PRE_PROCESS  => 'header',    # prefix each template
    EVAL_PERL => 1,    # evaluate Perl code blocks
    OUTPUT_PATH => '../baby/public/html/kcollection/'
};
my $db_handle = undef;

&main;

sub main() {
    my @categories = &fetch_categories();
    print "fetch categories over \n\n";
    my $template = Template->new($config);
    my $vars     = {
        zhunbei => $categories[0]->{sub_categories},
        huaiyun => $categories[1]->{sub_categories},
        fenmian => $categories[2]->{sub_categories},
    };
    $template->process( 'yun_baike.html', $vars, 'yun_baike.html' )
        || die $template->error();

    $db_handle = &get_db_handle();

=x
    $db_handle->prepare('delete from kcollection_article where sid=0')
        ->execute();
=cut

    for my $cate (@categories) {
        for ( @{ $cate->{sub_categories} } ) {
            my @article_list = reverse @{ &fetch_list_page( $_->{url} ) };
            for my $article (@article_list) {
                my $detail_html = &fetch_detail_page( $article->{url} );
                $db_handle->prepare(
                    'insert into kcollection_article set title=?,detail=?,cid=?,sid=0,source_url=? ON DUPLICATE KEY UPDATE detail=?'
                    )
                    ->execute( $article->{title}, $detail_html, $_->{cid},
                    $article->{url}, $detail_html );
            }
        }
    }
}

sub fetch_categories {
    my @categories = (
        {   type  => 'zhunbei',
            title => '备孕期',
            cid   => 1,
            url   => 'http://baby.sina.com.cn/zhunbei/'
        },    #备孕
        {   type  => 'huaiyun',
            title => '怀孕期',
            cid   => 2,
            url   => 'http://baby.sina.com.cn/huaiyun/'
        },    #怀孕
        {   type  => 'fenmian',
            title => '分娩期',
            cid   => 3,
            url   => 'http://baby.sina.com.cn/fenmian/'
        }     #分娩
    );
    for my $cate (@categories) {
        my $page_content
            = Spider->new( $cate->{url}, undef, undef, 1 )->fetch_page();
        $cate->{sub_categories}
            = &match_sub_categories( $page_content, $cate->{cid} );
    }
    return @categories;
}

sub match_sub_categories {
    my ( $page_content, $pid ) = @_;
    ($page_content) = $page_content =~ m{loadType.*?</ul>}gs;
    my %url_and_title  = $page_content =~ m{<a href="(.*?)">(.*?)</a>}gs;
    my @sub_categories = ();
    my $cid            = $pid * 20 + 1;
    while ( my ( $url, $title ) = each %url_and_title ) {
        push @sub_categories,
            {
            url   => $url,
            cid   => $cid++,
            title => $title
            };
    }
    return \@sub_categories;
}

sub fetch_list_page {
    my ($url) = @_;
    my $list_page_content = Spider->new($url)->fetch_page();
    ($list_page_content) = $list_page_content =~ m{list_text.*?<table}gs;
    my @title_and_url
        = $list_page_content =~ m{href="(.*?)" target="_blank">(.*?)</a>}gs;

    my @title_and_url_arr;
    for ( 0 .. ( @title_and_url / 2 - 1 ) ) {
        push @title_and_url_arr,
            {
            url   => $title_and_url[ $_ * 2 ],
            title => $title_and_url[ $_ * 2 + 1 ]
            };
    }
    return \@title_and_url_arr;
}

sub fetch_detail_page {
    my ($url) = @_;
    my $detail_page_content = Spider->new($url)->fetch_page();
    ($detail_page_content)
        = $detail_page_content
        =~ m{<!--显示正文 BEGIN-->(.*?)<!--显示正文 END-->}gs;
    return $detail_page_content;
}

sub get_options {
    my %args = ( cache => 1, );
    GetOptions( 'cache=i' => \$args{cache} );
    return \%args;
}

sub get_db_handle {
    return $db_handle if defined $db_handle;
    $db_handle = MyDB->db_conn('baby');
    $db_handle->prepare('set names utf8')->execute();
    return $db_handle;
}

