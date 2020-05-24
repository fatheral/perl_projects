#!/usr/bin/perl

use strict;
use warnings;

use locale;
use POSIX qw(locale_h);
setlocale(LC_CTYPE,"ru_RU.KOI8-R");
use Encode;
use URI::Escape;

use CGI::WebOut;
use CGI::WebIn(1);
use HTML::Template;

use DBI;

use POSIX qw( ceil );
use Time::HiRes qw( gettimeofday tv_interval );

use FindBin qw($Bin);
use lib "$Bin/include";

####################################

my $t0;
my $printbottom = 0;
my $cond = $GET{'cond'} || 'AND';
if ($cond ne 'AND' && $cond ne 'OR') {
	$cond = 'AND';
}

sub html_header {
	my $query = $GET{'q'} || '';
	my $full = $GET{'full'} || '';
	my $ot = $GET{'ot'} || '';
	my $do = $GET{'do'} || '';
	my $sizesort = $GET{'sizesort'} || '';
	my $html = HTML::Template->new(filename => "$Bin/templates/header.tmpl");
	$html->param('query' => $query, 'ot' => $ot, 'do' => $do);
	$html->param('full' => 1) if $full;
	$html->param('sizesort' => 1) if $sizesort;
	if ($cond eq "AND") {
		$html->param('and' => 1);
	} else {
		$html->param('or' => 1);
	}
	print $html->output;
}

sub html_footer {
	print "Этот отчет был сгенерирован ".localtime()."<br>\n" if $printbottom;
	my $html = "</body></html>";
	print $html;
}

sub do_sql {
	my $full = $GET{'full'} || '';
	my $sizesort = $GET{'sizesort'} || '';
	our ($dbh);
	my %params = @_;
	my $ot = 1024*$params{'ot'};
	my $do = 1024*$params{'do'};
	my @list = split(' ', $params{'query'});
	my $page = $GET{'page'} || 1;
	my $s;
	map {
		unless ($full) {
			$s .= qq{$cond lower(sname) LIKE '%'||lower(?)||'%' };
		} else {
			$s .= qq{$cond lower(sdir||'/'||sname) LIKE '%'||lower(?)||'%' };
		}
	} @list;
	$s .= qq{) AND (ssize BETWEEN ? AND ?) };
	$s =~ s/^$cond /(/;
	my $sql = qq{ SELECT sdir, sname, flag, ssize, host, to_char(time, 'YYYY-MM-DD HH24:mm:ss')
		      FROM smbsearch
		      WHERE }.$s." ORDER BY ";
	$sql .= "ssize DESC, " if $sizesort;
	$sql .= "lower(host), lower(sdir), lower(sname)";
	my $sql2 = qq{ SELECT COUNT(*) 
		       FROM smbsearch
		       WHERE }.$s;
	my ($num) = $dbh->selectrow_array($sql2, undef, (@list, $ot, $do));
	my $ref;
	if ($num == 0) {
		my $t1 = tv_interval($t0);
		print "<br />Нет строк, удовлетворяющих Вашему запросу. Время обработки запроса: <b>".sprintf("%.2f", $t1)."</b> сек.<br />\n";
	} elsif ($num <= 100) {
		$ref = $dbh->selectall_arrayref($sql, undef, (@list, $ot, $do));
		print_table('ref' => $ref, 'num' => $num);
	} else {
		my $firstind = 100*($page - 1) + 1;
		my $lastind = 100*$page;
		$sql = "SELECT *
			FROM ( SELECT a.*, ROWNUM rnum
			       FROM ( ".$sql." ) a
			       WHERE ROWNUM <= $lastind )
			WHERE rnum >= $firstind";
		$ref = $dbh->selectall_arrayref($sql, undef, (@list, $ot, $do));
		print_table('ref' => $ref, 'num' => $num);
	}
}

sub print_table {
	my %params = @_;
	my ($ref, $num, $query) = ($params{'ref'}, $params{'num'}, $GET{'q'});
	my @ftable;
	my ($pathstr, $fd, $size_cool, $href, $size_ed);
	my $page = $GET{'page'} || 1;
	my $ind = 100*($page - 1) + 1;
	map {
		my ($fdir, $fname, $flag, $fsize, $host, $time) = @$_;
		if ($flag eq 'd') {
			$fd = "DIR";
		} elsif ($flag eq 'f') {
			$fd = "";
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
 		
		(my $pathdir = $fdir) =~ s/\//\\/g;
		if ($fdir eq "/") {
			$href = "smb://$host$fdir$fname";
			$pathstr = "$pathdir<B>$fname</B>";
		} else {
			$href = "smb://$host$pathdir/$fname";
			$pathstr = "$pathdir\\<B>$fname</B>";
		}
		$pathstr = "\\\\<B>$host</B>$pathstr";

		$href = uri_escape(encode('cp1251', decode('koi8r', $href)), "^A-Za-z0-9\-_.!~*'()/:")
			if $ENV{'HTTP_USER_AGENT'} !~ /MSIE 6/;
		
		push (@ftable, {'fd' => $fd, 'pathstr' => $pathstr, 'size' => $size_cool, 'size_ed' => $size_ed, 
				'href' => $href, 'time' => $time, 'ind' => $ind});
		$ind++;
	} @$ref;

	my $html = HTML::Template->new(filename => "$Bin/templates/table.tmpl");
	if ($num > 100) {
		my $strnum = ceil($num/100);
		my @pages;
		for (my $i = 1; $i <= $strnum; $i++) {
			if (($i > $page - 10 && $i < $page + 10) || $i == 1 || $i == $strnum) {
				if ($i == $page) {
					push (@pages, {'page' => $i, 'query' => $query, 'ot' => $GET{'ot'}, 'do' => $GET{'do'}, 
						       'full' => $GET{'full'}, 'sizesort' => $GET{'sizesort'}, 'cond' => $cond});
				} else {
					push (@pages, {'page' => $i, 'query' => $query, 'ot' => $GET{'ot'}, 'do' => $GET{'do'}, 
						       'full' => $GET{'full'}, 'sizesort' => $GET{'sizesort'}, 'cond' => $cond, 'print' => 1});
				}
			}
		}
		$html->param('pages' => \@pages, 'strnum' => $strnum, 'page' => $page);
	}
	my $t1 = tv_interval($t0);
	$html->param('ftable' => \@ftable, 'num' => $num, 'sek' => sprintf("%.2f", $t1));
	print $html->output;
}

#########################################################

require "cfg.pl";

our %cfg;

$ENV{ORACLE_HOME} = $cfg{'oracle'}{'home'};
$ENV{NLS_LANG} = $cfg{'oracle'}{'lang_search'};
our $dbh = DBI->connect( "dbi:Oracle:host=$cfg{'db'}{'host'};sid=$cfg{'db'}{'sid'}", $cfg{'db'}{'login'}, $cfg{'db'}{'pass'}, {RaiseError => 1, AutoCommit => 0} ) or die $DBI::errstr;
  
html_header();
my $query = $GET{'q'} || '';
if ($query ne '') {
	$query =~ s/%/ /g;
	$query =~ s/_/ /g;
	$query =~ s/\s\s+/ /;
	$query =~ s/^\s*//;
	$query =~ s/\s*$//;
	my $flag = grep { length($_) < 3; } split(' ', $query);
	if ($query ne '' and $flag == 0) {
		my $ot = $GET{'ot'} || 0;
		my $do = $GET{'do'} || 1024*1024*1024*100;
		if ($ot !~ /^\d+$/ || $do !~ /^\d+$/) {
			print "<br />Неверный формат размера. Должен состоять <B>только</b> из цифр.\n";
		} elsif ($ot > $do) {
			print "<br />Минимальный размер должен быть <b>не больше</b> максимального.";
		} else {
			$t0 = [gettimeofday];		
			$printbottom = 1;
			do_sql('query' => $query, 'ot' => $ot, 'do' => $do);
		}
	} else {
		print q{<br />Все слова запроса меньше 3 символов (или нет других символов, кроме пробелов, '%', '_', '@').<br />}."\n";
	}
}
html_footer();

$dbh->disconnect();
