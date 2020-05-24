#!/usr/bin/perl

use strict;
use warnings;
use CGI::WebOut;
use CGI::WebIn;
use FindBin qw($Bin);


my $file = $POST{'myfile'};

if (exists $file->{'aborted'}) {
    print $file->{'aborted'};
}
else {
    print qq{<b>File name</b>: <a href="http://www.rirc.ru/share/files/$file->{'filename'}">$file->{'filename'}</a><br>};
    print qq{<b>File type</b>: $file->{'type'}<br>};
    my $newfile = "$Bin/files/$file->{'filename'}";
    system('cp', $file->{'file'}, $newfile) == 0 or die "Inner error! $!";
    print "<i>File successfully uploaded!</i>";
}

