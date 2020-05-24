#!/usr/bin/perl -w
use strict;

my $s = $ARGV[0];
$s =~ s#/$##;

open my $fil, '<', "db.txt";

while (my $str = <$fil>) {
	chomp ($str);
	my $i = index($str, $s);
	print $str."\n" if $i > -1;
}

close $fil;
