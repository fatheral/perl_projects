#!/usr/bin/perl

use strict;
use warnings;

#use locale;
#use POSIX qw(locale_h);
#setlocale(LC_CTYPE,"ru_RU.KOI8-R");

use POSIX qw(ceil);
use Encode;
use URI::Escape;
#use CGI::WebOut;
use CGI::WebIn;
use HTML::Template;
use DBI;

use FindBin qw($Bin);
use lib "$Bin/../";

require "cfg.pl";
our %cfg;

my $dbh = DBI->connect( "DBI:mysql:$cfg{'db'}{'dbname'}:$cfg{'db'}{'host'}", $cfg{'db'}{'login'}, $cfg{'db'}{'pass'} ) or die $DBI::errstr;
$dbh->do("SET NAMES '".$cfg{'charset_web'}."'");
print "Content-Type: text/html; charset=koi8-r\n\n";

my $miss_pages = 10;
my $dir_id = $GET{'dir'} || 1;
my $serv_id = $GET{'serv'} || '-';
my $page = $GET{'page'} || 1;
$page = 1 if $page !~ /^\d+$/;
if ($dir_id !~ /^\d+$/ or $serv_id !~ /^\d+$/) {
        print_serv();
} else {
        do_sql();
}

$dbh->disconnect();

####################################

sub do_sql {
	my $sql = qq{ SELECT ftp_dir, ftp_name, ftp_isdir, ftp_size, ftp_server, DATE_FORMAT( ftp_indtime, '%Y-%m-%d' ), ftp_file_id 
		      FROM ftpsearch, ftpserver
		      WHERE ftp_parent_id = ? 
		        AND ftpsearch.ftp_server_id = ftpserver.ftp_server_id
			AND ftpserver.ftp_server_id = ?
		      ORDER BY ftp_isdir, ftp_name };
	my $sql2 = qq{ SELECT COUNT(*) 
		       FROM ftpsearch, ftpserver
		       WHERE ftp_parent_id = ? 
		         AND ftpsearch.ftp_server_id = ftpserver.ftp_server_id 
			 AND ftpserver.ftp_server_id = ? };
	my $sql3 = qq{ SELECT ftp_dir, ftp_name, ftp_size, ftp_server, ftp_parent_id
		       FROM ftpsearch, ftpserver
		       WHERE ftp_file_id = ? AND ftp_isdir = 'd'
		         AND ftpsearch.ftp_server_id = ftpserver.ftp_server_id
			 AND ftpserver.ftp_server_id = ? };
	my ($num) = $dbh->selectrow_array($sql2, undef, $dir_id, $serv_id);
	my $dirref = $dbh->selectrow_arrayref($sql3, undef, $dir_id, $serv_id);
	my $ref;
	if (! defined $dirref) {
		print "Нет такой директории\n";
	} elsif ($num <= 100) {
		$ref = $dbh->selectall_arrayref($sql, undef, $dir_id, $serv_id);
		print_table('ref' => $ref, 'dirref' => $dirref, 'num' => $num);
	} else {
		my $firstind = 100*($page - 1);
		$sql = $sql." LIMIT $firstind, 100";
		$ref = $dbh->selectall_arrayref($sql, undef, $dir_id, $serv_id);
		print_table('ref' => $ref, 'dirref' => $dirref, 'num' => $num);
	}
}

sub print_table {
	my %params = @_;
	my ($ref, $dirref, $num) = ($params{'ref'}, $params{'dirref'}, $params{'num'});
	my @ftable;
	my ($fd, $size_cool, $href, $size_ed);
	my $ind = 100*($page - 1) + 1;
	my ($pdir, $pname, $psize, $pserv, $parent_dir) = @$dirref;
	
	foreach (@$ref) {
		my ($fdir, $fname, $flag, $fsize, $server, $time, $child_dir) = @$_;
		if ($flag eq 'd') {
			$fd = 'class="fd"';
			$href = '?dir='.$child_dir.'&amp;serv='.$serv_id;
		} elsif ($flag eq 'f') {
			$fd = 'class="ff"';
			$href = ($fdir eq '/') ? 'ftp://'.$server.$fdir.$fname : 'ftp://'.$server.$fdir.'/'.$fname;
			$href = uri_escape(encode('cp1251', decode($cfg{'charset_web'}, $href)), "^A-Za-z0-9\-_.!~*'()/:") if
				$ENV{'HTTP_USER_AGENT'} !~ /MSIE 6/;
		}
		
                if ($fsize >= 1024 && $fsize < 1024*1024) {
			$size_cool = sprintf("%.1f", $fsize/1024);
                        $size_ed = "Кб";
		} elsif ($fsize >= 1024*1024 && $fsize < 1024*1024*1024) {
                        $size_cool = sprintf("%.1f", $fsize/(1024*1024));
                        $size_ed = "Мб";
                } elsif ($fsize >= 1024*1024*1024) {
                        $size_cool = sprintf("%.1f", $fsize/(1024*1024*1024));
                        $size_ed = "Гб";
                } else {
                        $size_cool = "$fsize.0";
                        $size_ed = "байт"
                }
 		
		push (@ftable, {'fd' => $fd, 'name' => $fname, 'size' => $size_cool, 'size_ed' => $size_ed, 
			'href' => $href, 'time' => $time, 'ind' => $ind});
		$ind++;
	}

	my $html = HTML::Template->new(filename => "$Bin/../templates/fdir.tmpl");
	if ($num > 100) {
		my $strnum = sprintf ("%.0f", ceil($num/100) );
		my @pages;
		for (my $i = 1; $i <= $strnum; $i++) {
			if (($i > $page - 10 && $i < $page + 10) || ($i == 1) || ($i == $strnum)) {
				if ($i == $page) {
					push (@pages, {'page' => $i} );
				} 
				else {
					push (@pages, {'page' => $i, 'dir' => $dir_id, 'serv' => $serv_id} );
				}
				if (($i == 1 && $page - $miss_pages > 1)
				  || ($i == $page + $miss_pages - 1 && $page + $miss_pages < $strnum)) {
					push (@pages, { 'page' => '...' });
				}
			}
		}
		$html->param('pages' => \@pages, 'strnum' => $strnum, 'page' => $page);
	}
	$html->param('ftable' => \@ftable, 'num' => $num);
	
	my ($top_name, $top_href);
	if (defined $parent_dir) {
		$top_name = ($pdir eq '/') ? 'ftp://'.$pserv.$pdir.$pname : 'ftp://'.$pserv.$pdir.'/'.$pname;
		$html->param('parent_dir' => $parent_dir, 'parent_serv' => $serv_id);
	} else {
		$top_name = 'ftp://'.$pserv;
	}
	$top_href = $top_name;
	$top_href = uri_escape(encode('cp1251', decode($cfg{'charset_web'}, $top_href)), "^A-Za-z0-9\-_.!~*'()/:") if
		$ENV{'HTTP_USER_AGENT'} !~ /MSIE 6/;
	my $fullsize;
	if ($psize >= 1024 && $psize < 1024*1024) {
		$fullsize = sprintf("%.1f", $psize/1024)." Кб";
	} elsif ($psize >= 1024*1024 && $psize < 1024*1024*1024) {
		$fullsize = sprintf("%.1f", $psize/(1024*1024))." Мб";
	} elsif ($psize >= 1024*1024*1024) {
		$fullsize = sprintf("%.1f", $psize/(1024*1024*1024))." Гб";
	} else {
		$fullsize = $psize." байт";
	}
	$html->param('top_name' => $top_name, 'top_href' => $top_href, 'fullsize' => $fullsize);
	
	print $html->output;
}

sub print_serv {
	my $ref = $dbh->selectall_arrayref(qq{ SELECT ftp_server, ftp_size, ftpserver.ftp_server_id
					       FROM ftpsearch, ftpserver
					       WHERE ftp_file_id = 1
					         AND ftpsearch.ftp_server_id = ftpserver.ftp_server_id
					       ORDER BY ftp_size DESC });
	my @serv;
	push (@serv, {'server' => 'ftp://'.$_->[0], 'size' => sprintf("%.1f", $_->[1]/(1024*1024*1024)), 'dir' => 1, 'serv' => $_->[2] }) foreach @$ref;
	my $html = HTML::Template->new(filename => "$Bin/../templates/fdserv.tmpl");
	$html->param('serv' => \@serv);
	print $html->output;
}

