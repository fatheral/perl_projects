#!/usr/bin/perl -w
use strict;

my $d = $ARGV[0];
$d =~ s#/$## if $d ne '/';

open my $fil, '>', "db.txt";

my @dirs = ();
if (! -e $d || ! -d $d) {
	print "Hasn't found dir (or permission is required) with name $d \n";
} elsif (-r $d) {
	push (@dirs, $d);
	while (@dirs > 0) {
		my $dir = shift (@dirs);
		print $fil "$dir\n";
		opendir (D, $dir);
		my @all = readdir(D);
		map {
			if ($_ ne '.' && $_ ne '..') {
				my $f = $dir."/".$_;
				if (-d $f) {
					if (-x $dir && -r $f) {
						push (@dirs, $f);
					} else {
						print $fil "$f\n";
					}
				} else {
					print $fil "$f\n";
				}
			}
		} @all;
		closedir(D);
	}
} else {
	print $fil $d;
}

close $fil;
