#!/usr/bin/perl

use strict;
use warnings;

use locale;
use POSIX qw(locale_h);
setlocale(LC_CTYPE,"ru_RU.KOI8-R");

use IMDB::Film;
use Lingua::RU::PhTranslit;
#use CGI::WebOut;
use CGI::WebIn;
use HTML::Template;
use Encode;
use DBI;
use FindBin qw($Bin);

require "$Bin/../link_cfg.pl";
our %cfg;

my $film_orig = $GET{'film'} || '';
$film_orig =~ s/[^\w().-]/ /g;
$film_orig =~ s/_/ /g;
$film_orig =~ s/\s+/ /g;
$film_orig =~ s/^\s*//;
$film_orig =~ s/\s*$//;
$film_orig =~ s/^\s+$//;

my $dbh = DBI->connect( "DBI:mysql:$cfg{'db'}{'dbname'}:$cfg{'db'}{'host'}", $cfg{'db'}{'login'}, $cfg{'db'}{'pass'} ) or die $DBI::errstr;
$dbh->do("SET NAMES 'koi8r'");
my $html = HTML::Template->new(filename => "$Bin/../templates/imdblink.tmpl");
my ($err_imdb, $err_link);

if ($film_orig) {
        imdb();
        links();
}

$dbh->disconnect();
$html->param('film' => $film_orig);
$html->param('err_imdb' => $err_imdb) if $err_imdb;
$html->param('err_link' => $err_link) if $err_link;

print "Content-Type: text/html; charset=koi8-r\n\n";
print $html->output();

sub imdb {
	my $film = koi2phtr($film_orig);
	my $imdbObj = new IMDB::Film(crit => $film);
	if($imdbObj->status) {
		$html->param('title' => $imdbObj->title() );
		$html->param('year' => $imdbObj->year() );
		my $genre = join ', ', @{ $imdbObj->genres() };
		$html->param('genre' => $genre );
		my $country = join ', ', @{ $imdbObj->country() };
		$html->param('country' => $country );
		my $director = join ', ', map { $_->{'name'} } @{ $imdbObj->directors() };
		$html->param('director' => $director );
		my ($rating, $votes) = $imdbObj->rating();
		$rating ||= 0;
		$votes ||=0;
		$html->param('rating' => $rating, 'votes' => $votes );
		$html->param('link' => 'http://www.imdb.com/title/tt'.$imdbObj->code() );
	} else {
		$err_imdb = "Не могу найти фильм (<b>".$imdbObj->error."</b>) в IMDB. Попробуйте уточнить строку запроса";
	}
}

sub links {
	my @list = split(' ', $film_orig);
	my $s;
	my $n = @list;
	$s .= q{AND CONCAT(title, '/', original) LIKE CONCAT('%', ?, '%') } foreach 1..$n;
	$s =~ s/^AND//;
	my $sql = qq{	SELECT title, original, pid, text
			FROM slaed_catalog_movie
			WHERE $s 
			ORDER BY title, original };
	my $ref = $dbh->selectall_arrayref($sql, undef, @list) or die $DBI::errstr;
	if (@$ref) {
		my @links;
		foreach (@$ref) {
			my ($title, $origtitle, $pid, $desc) = ($_->[0], $_->[1], $_->[2], $_->[3]);
			push (@links, {'movie' => $origtitle ? $title.' / '.$origtitle : $title, 'pid' => $pid, 'desc' => $desc});
		}
		$html->param('links' => \@links);
	}
	else {
		$err_link = "На links.bks-tv.ru не могу найти фильм с таким названием. Попробуйте уточнить строку запроса";
	}
}

