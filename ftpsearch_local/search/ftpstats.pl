#!/usr/bin/perl

use strict;
use warnings;

use locale;
use POSIX qw(locale_h);
setlocale(LC_CTYPE,"ru_RU.KOI8-R");

use CGI::WebOut;
use HTML::Template;
use DBI;

use FindBin qw($Bin);
use lib "$Bin/include";

require "cfg.pl";
our %cfg;

###
my @deny_ip = ('192.168.100.66');
if (grep { $_ eq $ENV{'REMOTE_ADDR'} } @deny_ip) {
	print "Your IP is blocked ;-)";
	exit;
}
###

my $num = 20;
my $dbh = DBI->connect( "DBI:mysql:$cfg{'db'}{'dbname'}:$cfg{'db'}{'host'}", $cfg{'db'}{'login'}, $cfg{'db'}{'pass'} ) or die $DBI::errstr;
$dbh->do("SET NAMES 'koi8r'");

####################################

sub top20 {
	my $n = 20;
	my (@top_ip, @top_req);

	my $ref_req = $dbh->selectall_arrayref(qq{ SELECT ftp_req, count(*)
						   FROM ftpreq
						   GROUP BY ftp_req
						   ORDER BY count(*) DESC
						   LIMIT 0, $n } ) or die $DBI::errstr;
	map { push (@top_req, {'req' => $_->[0], 'num' => $_->[1]}) } @$ref_req;

	my $ref_ip = $dbh->selectall_arrayref(qq{ SELECT ftp_req_ip, count(*)
						   FROM ftpreq
						   GROUP BY ftp_req_ip
						   ORDER BY count(*) DESC
						   LIMIT 0, $n } ) or die $DBI::errstr;
	map { push (@top_ip, {'ip' => $_->[0], 'num' => $_->[1]}) } @$ref_ip;
	return (\@top_ip, \@top_req);
}

sub last20 {
	my $n = 20;
	my @last_req;
	my $ref_last = $dbh->selectall_arrayref(qq{ SELECT ftp_req, ftp_req_ip, ftp_req_time
						    FROM ftpreq
						    ORDER BY ftp_req_time DESC
						    LIMIT 0, $n } ) or die $DBI::errstr;
	map { push (@last_req, { 'req' => $_->[0], 'ip' => $_->[1], 'time' => $_->[2]}) } @$ref_last;
	return \@last_req;
}


	
sub servinfo {
	my $ref = $dbh->selectall_arrayref(q{ SELECT ftp_server, ftp_size
					      FROM ftpsearch, ftpserver
					      WHERE ftp_file_id = 1
					        AND ftpserver.ftp_server_id = ftpsearch.ftp_server_id
					      ORDER BY ftp_size DESC }) or die $DBI::errstr;
	my @serv;
	push (@serv, {'server' => 'ftp://'.$_->[0], 'size' => sprintf("%.1f", $_->[1]/(1024*1024*1024))}) foreach @$ref;

	return (\@serv);
}

####################################

my ($top_ip, $top_req) = top20();
my $last_req = last20();
my $servinfo = servinfo();

my $html = HTML::Template->new(filename => "$Bin/templates/stats.tmpl");
$html->param('top_ip' => $top_ip, 'top_req' => $top_req, 'last_req' => $last_req, 'servinfo' => $servinfo);
print $html->output;

$dbh->disconnect();
