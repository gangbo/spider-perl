#!/usr/bin/env perl
use strict;
use warnings;

&sub1;
&sub2;

sub sub1 {
    my @arr;
    for(1..1000) {
        push @arr,$_;
    }
    return @arr;
}

sub sub2 {
    my @arr = map { $_ } (1..1000);
}

=head
使用Devel::NYTProf 测试程序效率
用法参考 http://chenlinux.com/2010/05/07/performance-optimization-of-perl-script-by-devel-nytprof/
perl -d:NYTProf DevelNYTProf-sample.pl
=cut
