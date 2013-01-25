#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw/cmpthese/;

cmpthese(500,
    {
        'map' => \&testmap,
        'for' => \&testfor,
});

sub testmap {
    map {$_=0} ( 1 .. 1000);
}

sub testfor {
    for(1..1000){
        $_ = 0;
    }
}

=head
测试map和for的效率
perl benchmark-sample.pl
=cut
