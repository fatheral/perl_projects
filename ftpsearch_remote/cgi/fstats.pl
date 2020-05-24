#!/usr/bin/perl

use strict;
use warnings;

use locale;
use POSIX qw(locale_h floor);
setlocale(LC_CTYPE,"ru_RU.KOI8-R");

use CGI::WebOut;
use HTML::Template;
use DBI;
use GD::Graph::bars;

use FindBin qw($Bin);
use lib "$Bin/../";

require "cfg.pl";
our %cfg;

my $n = 20;
my $dbh = DBI->connect( "DBI:mysql:$cfg{'db'}{'dbname'}:$cfg{'db'}{'host'}", $cfg{'db'}{'login'}, $cfg{'db'}{'pass'} ) or die $DBI::errstr;
$dbh->do("SET NAMES '".$cfg{'charset_web'}."'");

my $rand_req = rand20();
my $servinfo = servinfo();
my $num_of_req = $dbh->selectrow_array("SELECT ftp_count FROM ftpcount");

my $html = HTML::Template->new(filename => "$Bin/../templates/fstats.tmpl");
$html->param('n' => $n, 'rand_req' => $rand_req, 'servinfo' => $servinfo, 'num_of_req' => $num_of_req);
my $day_req = grafik();
$html->param('picname' => $cfg{'picture_file'}, 'day_req' => $day_req);
print $html->output;

$dbh->disconnect();

####################################

sub rand20 {
	my @rand_req;
	my $ref_rand = $dbh->selectall_arrayref(qq{
		SELECT ftp_req, ftp_req_ip, ftp_req_time
		FROM ftpreq
		WHERE mod(ftp_req_id, 100) = round(100*rand())
		ORDER BY ftp_req_time DESC
		LIMIT 0, $n
	} ) or die $DBI::errstr;
	foreach (@$ref_rand) {
		push @rand_req, { 
			'req'  => $_->[0],
			'ip'   => $_->[1] =~ /^(?:10|172)\.[^.]+\.([^.]+)\.([^.]+)$/ ? 256*$1 + $2 : $_->[1],
			'time' => $_->[2],
		};
	}
	return \@rand_req;
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

sub grafik {
	my $ref = $dbh->selectall_arrayref(q{
		SELECT hour(ftp_req_time) h, count(1) cnt, day(ftp_req_time) d, month(ftp_req_time) m, year(ftp_req_time) y
		FROM ftpreq
		WHERE ftp_req_time > date_sub(now(), interval 1 day)
		GROUP BY y, m, d, h
		ORDER BY y, m, d, h
	}) or die $DBI::errstr;
	
	my (@hours, @requests);
	my $day_req = 0;
	foreach (@$ref) {
		push @hours, $_->[0];
		push @requests, $_->[1];
		$day_req += $_->[1];
	}
	
	my $graph = GD::Graph::bars->new(500, 300);
	$graph->set(
		x_label		=> 'Hour',
		y_label		=> 'Requests',
		title		=> 'Number of requests through last day',
		show_values	=> 1,
		bar_spacing	=> 2,
		labelclr	=> 'dbrown',		#axis names colour
		textclr		=> 'dbrown',		#name of pic colour
		axislabelclr	=> 'black',		#axis values colour
		valuesclr	=> 'blue',		#bar values colour
		fgclr		=> 'black',		#axis border colour
		shadow_depth	=> 1,			#use shadow
		shadowclr	=> 'gray',		#shadow color
		dclrs		=> [ 'lgray' ],		#bar colour
	) or warn $graph->error;
	my $image = $graph->plot([\@hours, \@requests]) or die $graph->error;

	my $pic = "$cfg{'picture_path'}/$cfg{'picture_file'}";

	open my $fh, '>', $pic or die('Cannot open file for writing');
	binmode $fh;
	print $fh $image->png;
	close $fh;
	return $day_req;
}

