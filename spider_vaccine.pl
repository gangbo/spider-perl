#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use File::Util;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Getopt::Long;
use List::Util qw/first/;
use MyDB;

#use utf8;
use Data::Dumper;

#main();

sub main {
    my $args = get_options();
    my $url =
      'http://www.babytree.com/promo/yimiao/index_sub.php?sub_action=sub_one';
    my $content = get_remote_content( $args->{cache}, $url );
    my @details = filter($content);

    #print Dumper \@details;
    my @vaccine_jihuanei = &parse_csv2hashref();

    #    print Dumper \@vaccine_jihuanei;
    my $db = MyDB->db_conn('baby');
    $db->prepare('set names utf8')->execute();
    my @list;

    for (@vaccine_jihuanei) {
        my $row = {
            months  => $_->[0],
            title   => $_->[1],
            times   => $_->[2],
            summary => $_->[3],
            content => ''
        };
        my $pattern = $row->{title};
        if ( $row->{title} =~ /(.*?)疫苗\((.*?)\)/ ) {
            $pattern = $1 . '|' . $2;
        }
        for my $cts (@details) {
            if ( $cts =~ /$pattern/gs ) {
                $row->{content} = $cts;
                last;
            }
            print Dumper $row;
            push @list, $row;
        }

        #print Dumper $row;
        my $sth =
          $db->prepare(
'replace into kcollection_yimiao(title,content,summary,months,type) values(?,?,?,?,2)'
          );
        $sth->execute( $row->{title}, $row->{content}, $row->{summary},
            $row->{months} );
    }
    print Dumper \@list;
}

sub filter {
    my $content = shift;
    my @arr = $content =~ /class="snf-win sw\d+?".*?>(.*?)<\/div>/sg;
    return @arr;
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

sub get_vaccine_jihuanei_list {
    my $f        = File::Util->new();
    my $contents = $f->load_file('yimiao.html');
    $contents =~ s/<!.*?>//gs;
    $contents =~ s/<\/?p>|<\/?span>|<\/?b>|<\/?o:p>//gs;
    $f->write_file(
        file    => 'yimiao.html',
        content => $contents,
        bitmask => 0644
    );
    $contents =~
/#jihuaneiyimiao-begin.*?<table.*?<table(.*?)<\/table>.*?<table(.*?)<\/table>.*#jihuaneiyimiao-end/gs;
    $contents = $1 . $2;
    $contents =~ s/<\/?p>|<\/?span>|<\/?b>|<\/?o:p>|<br>//gs;
    my @tr = $contents =~ /(<tr.*?<\/tr>)/gs;
    shift @tr;

    #    print Dumper \@tr;
    my $months = {
        '一' => 1,
        '二' => 2,
        '三' => 3,
        '四' => 4
    };
    my $csv_str = "接种时间,接种疫苗,次数,可预防的传染病\n";
    my @arr_list;
    for (@tr) {
        $_ =~ s/\n|\r| //g;
        if (
/<td[^>]*?>([^td]*?)<\/td>\s*?<td[^>]*?>([^td]*?)<\/td>\s*?<td[^>]*?>([^td]*?)<\/td>\s*?<\/tr>/gs
          )
        {
            $csv_str .= ',' . $1 . ',' . $2 . ',' . $3 . "\n";
            my $tmp_arr = [ $1, 1, $3 ];
            my ($month) = $2 =~ /第(.*?)次/;
            $tmp_arr->[1] = $months->{$month} || 1;
            push @arr_list, $tmp_arr;
        }
    }
    $f->write_file(
        file    => 'yimiao.csv',
        content => $csv_str,
        bitmask => 0644
    );
    return @arr_list;
}

sub parse_csv2hashref {
    open( my $fh, '<', 'yimiao-utf8.csv' ) or die "cannot open file";
    my $months = {
        '一' => 1,
        '二' => 2,
        '三' => 3,
        '四' => 4
    };
    my @arr;
    while (<$fh>) {
        s/[\n\r]//gs;
        my $tmp = [ split /,/, $_ ];
        my ($month) = $tmp->[2] =~ /第(.*)次/;
        $tmp->[2] = $months->{$month};
        push @arr, $tmp;
    }
    shift @arr;
    return @arr;
}
&get_vaccine_jihuawai_list();
sub get_vaccine_jihuawai_list {
    my $f        = File::Util->new();
    my $contents = $f->load_file('yimiao.html');
    ($contents) =
      $contents =~ /#jihuawai-begin.*?<table.*?>(.*)<\/table>.*#jihuawai-end/gs;

    #    print $contents;
    $contents =~ s/[\n\r\t\s ]//gs;
    my @tr =
      $contents =~ /<tr>\s*?<td>(.*?)<\/td>\s*?<td>(.*?)<\/td>\s*?<\/tr>/gs;
    my $csv_str = '';
    my $db      = MyDB->db_conn('baby');
    $db->prepare('set names utf8')->execute();
    my $isNewLine = 1;
    my $row = { title =>'',content=>'',months=>0};
    for (@tr) {
        $csv_str .= $_;
        #$csv_str .= $isNewLine ? ',' : "\n";
        if($isNewLine) {
            $row->{title} = $_;
        }else{
            $row->{content} = $_;
            $row->{summary} = $_;
            my $sth =
              $db->prepare(
'replace into kcollection_yimiao(title,content,summary,months,type) values(?,?,?,?,3)'
              );
            $sth->execute(
                $row->{title},   $row->{content},
                $row->{summary}, $row->{months}
            );
        }
        $isNewLine ^= 1;
    }

=x
    $f->write_file(
        file    => 'yimiao_jihuawai.csv',
        content => $csv_str,
        bitmask => 0644
    );
=cut

}

