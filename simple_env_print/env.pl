#!/usr/bin/perl

print "Content-type: text/html\n\n";
foreach my $k (keys %ENV) {
    print "<b>$k</b>: ", $ENV{$k}, "<br>\n" if $k =~ /^HTTP_/;
}

