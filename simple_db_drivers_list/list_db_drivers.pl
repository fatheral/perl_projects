#!/usr/bin/perl -w

 use strict;
 use DBI;
 print "Available Database Drivers:\n";
 print "*" x 40, "\n";
 print join("\n", DBI->available_drivers()), "\n\n";

