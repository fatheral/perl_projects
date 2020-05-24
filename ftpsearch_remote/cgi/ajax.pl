#!/usr/bin/perl

use strict;
use warnings;

use locale;
use POSIX qw(locale_h ceil);
setlocale(LC_CTYPE,"ru_RU.KOI8-R");

use Encode;
use CGI::WebIn;
#use URI::Escape;
use DBI;

use FindBin qw($Bin);
require "$Bin/../cfg.pl";
our %cfg;

#########################################################

my $dbh = DBI->connect( "DBI:mysql:$cfg{'db'}{'dbname'}:$cfg{'db'}{'host'}", $cfg{'db'}{'login'}, $cfg{'db'}{'pass'} ) or die $DBI::errstr;
$dbh->do("SET NAMES '".$cfg{'charset_web'}."'");

my $query = encode('koi8-r', decode('utf8', $GET{'q'} || ''));

#use CGI::WebOut;
#Header('Content-Type: text/html; charset=koi8-r');
print "Content-Type: text/html; charset=koi8-r\n\n";

$query =~ s/[^\w().-]/ /g;
$query =~ s/_/ /g;
$query =~ s/\s+/ /g;
$query =~ s/^\s*//;
$query =~ s/\s*$//;
$query =~ s/^\s+$//;

exit unless $query;

my $ref = $dbh->selectall_arrayref(q{	SELECT ftp_req, ftp_req_cnt
					FROM ftpcumreq
					WHERE ftp_req LIKE CONCAT(?, '%')
					ORDER BY ftp_cum_req_id
					LIMIT 0,5 }, undef, $query) or die $DBI::errstr;

exit unless @$ref;

print '<div class="autocomplete">';
print '<table width="100%">';
foreach (@$ref) {
	my ($req, $num) = @$_;
	print '<tr>';
	print '<td align="left"><a href="#" onclick="javascript:setq(this.innerHTML)">', $req, '</a></td>';
	print '<td align="right" style="color: green;">', $num, '</td>';
	print '</tr>';
}
print '</table>';
print '</div>';

$dbh->disconnect();

