#!/usr/bin/perl

use strict;
use warnings;

use locale;
use POSIX qw(locale_h ceil);
setlocale(LC_CTYPE,"ru_RU.KOI8-R");

use CGI::WebIn;
use HTML::Template;

use FindBin qw($Bin);
use lib "$Bin/../";

require "cfg.pl";

our %cfg;

####################################

my %ext_spec = (
	'ALL'		=> 1,
	'DIR'		=> 1,
	'VIDEO'		=> 1,
	'AUDIO'		=> 1,
	'DOC'		=> 1,
	'PICTURE'	=> 1,
	'UNIX'		=> 1,
	'CDIMAGE'	=> 1,
	'ARCHIVE'	=> 1,
	'WINEXE'	=> 1,
);
my $target = $GET{'target'} || 'ALL';
$target = 'ALL' if ! exists $ext_spec{$target};

my %cond_all = (
	'AND'	=> 1,
	'OR'	=> 1,
);
my $cond = $GET{'cond'} || 'AND';
$cond = 'AND' if ! exists $cond_all{$cond};

my $query = $GET{'q'} || '';
$query =~ s/[^\w().-]/ /g;
$query =~ s/_/ /g;
$query =~ s/\s+/ /g;
$query =~ s/^\s*//;
$query =~ s/\s*$//;
$query =~ s/^\s+$//;


my ($ot, $do, $full, $sizesort) = ('', '', '', '');
if (exists $GET{'full'}) {
	$full = $GET{'full'} if $GET{'full'} eq 'on';
}
if (exists $GET{'sizesort'}) {
	$sizesort = $GET{'sizesort'} if $GET{'sizesort'} eq 'on';
}
if (exists $GET{'ot'}) {
	$ot = $GET{'ot'} if $GET{'ot'} =~ /^\d+$/;
}
if (exists $GET{'do'}) {
	$do = $GET{'do'} if $GET{'do'} =~ /^\d+$/;
}

my $html = HTML::Template->new(filename => "$Bin/../templates/extsearch.tmpl");
$html->param('query' => $query, 'ot' => $ot, 'do' => $do);
$html->param('full' => $full) if $full;
$html->param('sizesort' => $sizesort) if $sizesort;
$html->param($cond => 1);
$html->param($target => 1);

print "Content-Type: text/html; charset=koi8-r\n\n";
print $html->output;
