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
use constant { SERVICE_ID => '11', };

use Data::Dumper;

# 'http://www16.zzu.edu.cn/qtss/zzjpoem1.dll/query';

&main();

sub main {
    &fetch_list_xing();

}

sub fetch_list_xing {
    my $site_url     = 'http://www16.zzu.edu.cn/qtss/zzjpoem1.dll/query';
    my $page_content = Spider->new(
        $site_url, 'post',
        { B5 => '诗人浏览' },
    )->fetch_page();
    ($page_content) = $page_content =~ m{td width="600">(.*?)</table>}gs;

        print  $page_content;
}

