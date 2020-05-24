#!/usr/bin/perl

use strict;
use warnings;

use locale;
use POSIX qw(locale_h ceil);
setlocale(LC_CTYPE,"ru_RU.KOI8-R");

use Encode;
use URI::Escape;
use CGI::WebOut;
use CGI::WebIn(1);
use HTML::Template;
use DBI;
use Time::HiRes qw( gettimeofday tv_interval );

use FindBin qw($Bin);
use lib "$Bin/include";

####################################

my @deny_ip = ('192.168.100.66');
if (grep { $_ eq $ENV{'REMOTE_ADDR'} } @deny_ip) {
	print "Your IP is blocked ;-)";
	exit;
}

my $t0;
my $printbottom = 0;

my $ext = q{AND (ftp_isdir = 'f' AND right(ftp_name, instr(reverse(ftp_name), '.') - 1) IN };
my %ext_spec = (
	'ALL'		=> '',
	'DIR'		=> q{AND (ftp_isdir = 'd')},
	'VIDEO'		=> $ext.q{('mpeg', 'mpg', 'avi', 'dat', 'asf', 'ogm', 'vob', 'm2v', 'wmv', 'mkv', 'flv'))},
	'AUDIO'		=> $ext.q{('mp3', 'wav', 'au', 'aif', 'aiff', 'ogg', 'mpc', 'flac', 'fla', 'ape', 'wma', 'ra', 'rm', 'vqf', 'ac3'))},
	'DOC'		=> $ext.q{('txt', 'rtf', 'doc', 'htm', 'html', 'pdf', 'ps', 'djv', 'djvu', 'chm'))},
	'PICTURE'	=> $ext.q{('bmp', 'gif', 'jpeg', 'jpg', 'pbm', 'pcx', 'png', 'pnm', 'ppm', 'psd', 'tiff', 'tif', 'xbm', 'xpm'))},
	'UNIX'		=> $ext.q{('rpm', 'deb', 'spec', 'ebuild', 'patch'))},
	'CDIMAGE'	=> $ext.q{('bin', 'iso', 'mdf', 'bwt', 'cdi', 'nrg', 'mds', 'ccd', 'cue'))},
	'ARCHIVE'	=> $ext.q{('arj', 'zip', 'rar', 'arc', 'lha', 'lzh', 'ace', 'tar', 'gz', 'gzip', 'bz2', 'tgz', 'tbz2', 'zoo', 'cab', 'jar', '7z', 'z'))},
	'WINEXE'	=> $ext.q{('exe', 'msi', 'dll'))},
);
my $target = $GET{'target'} || 'ALL';
$target = 'ALL' if ! exists $ext_spec{$target};

my %cond_all = (
	'AND'	=> 1,
	'OR'	=> 1,
);
my $cond = $GET{'cond'} || 'AND';
$cond = 'AND' if ! exists $cond_all{$cond};

my $path = 'ftpdir.pl?';

sub html_header {
	my $query = $GET{'q'} || '';
	my $full = $GET{'full'} || '';
	my $sizesort = $GET{'sizesort'} || '';
	my $ot = $GET{'ot'} || '';
	my $do = $GET{'do'} || '';
	my $html = HTML::Template->new(filename => "$Bin/templates/header.tmpl");
	$html->param('query' => $query, 'ot' => $ot, 'do' => $do);
	$html->param('full' => $full) if $full;
	$html->param('sizesort' => $sizesort) if $sizesort;
	$html->param($cond => 1);
	$html->param($target => 1);
	print $html->output;
}

sub html_footer {
	if ($printbottom) {
		our $dbh;
		my ($count) = $dbh->selectrow_array('SELECT ftp_count FROM ftpcount');
		$count++;
		$dbh->do("UPDATE ftpcount SET ftp_count = ?", undef, $count);
		print 'Этот отчет был сгенерирован '.localtime().'.<br>'."\n";
		print 'Поиском воспользовались <B>'.$count.'</B> раз.';
	}
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
			$s .= qq{$cond ftp_name LIKE CONCAT('%', ?, '%') };
		} else {
			$s .= qq{$cond CONCAT(IF(ftp_dir = '/', '', ftp_dir), '/', ftp_name) LIKE CONCAT('%', ?, '%') };
		}
	} @list;
	$s =~ s/^$cond /(/;
	$s .= qq{AND ftp_name IS NOT NULL) AND (ftp_size BETWEEN ? AND ?) };
	my $sql = qq{ SELECT ftp_dir, ftp_name, ftp_isdir, ftp_size, ftp_server, DATE_FORMAT( ftp_indtime, '%Y-%m-%d' ), ftp_file_id, ftpsearch.ftp_server_id 
		      FROM ftpsearch, ftpserver
		      WHERE ftpsearch.ftp_server_id = ftpserver.ftp_server_id AND }.$s.$ext_spec{$target}.' ORDER BY ';
	$sql .= 'ftp_size DESC, ' if $sizesort;
	$sql .= 'ftp_server, ftp_dir, ftp_name';
	my $sql2 = qq{ SELECT COUNT(*) 
		       FROM ftpsearch, ftpserver
		       WHERE ftpsearch.ftp_server_id = ftpserver.ftp_server_id AND }.$s.$ext_spec{$target};
	my ($num) = $dbh->selectrow_array($sql2, undef, (@list, $ot, $do));
	my $ref;
	if ($num == 0) {
		my $t1 = tv_interval($t0);
		print '<br>Нет строк, удовлетворяющих Вашему запросу. Время обработки запроса: <b>'.sprintf("%.2f", $t1).'</b> сек.<br>'."\n";
	} elsif ($num <= 100) {
		$ref = $dbh->selectall_arrayref($sql, undef, (@list, $ot, $do));
		print_table('ref' => $ref, 'num' => $num);
	} else {
		my $firstind = 100*($page - 1);
		$sql = $sql." LIMIT $firstind, 100";
		$ref = $dbh->selectall_arrayref($sql, undef, (@list, $ot, $do));
		print_table('ref' => $ref, 'num' => $num);
	}
}

sub print_table {
	my $full = $GET{'full'} || '';
	my %params = @_;
	my ($ref, $num, $query) = ($params{'ref'}, $params{'num'}, $GET{'q'});
	my @ftable;
	my ($pathstr, $fd, $size_cool, $href, $size_ed);
	my $page = $GET{'page'} || 1;
	my $ind = 100*($page - 1) + 1;
	map {
		my ($fdir, $fname, $flag, $fsize, $server, $time, $ftp_id, $serv_id) = @$_;
		$server = 'ftp://'.$server;
		if ($flag eq 'd') {
			$fd = 'DIR';
			$href = $path.'dir='.$ftp_id.'&amp;serv='.$serv_id;
		} elsif ($flag eq 'f') {
			$fd = "";
			$href = ($fdir eq '/') ? $server.$fdir.$fname : $server.$fdir.'/'.$fname;
			$href = uri_escape(encode('cp1251', decode('koi8r', $href)), "^A-Za-z0-9\-_.!~*'()/:") if
				$ENV{'HTTP_USER_AGENT'} !~ /MSIE 6/;
		}
		
                if ($fsize >= 1024 && $fsize < 1024*1024) {
			$size_cool = sprintf("%.1f", $fsize/1024);
                        $size_ed = 'Кб';
		} elsif ($fsize >= 1024*1024 && $fsize < 1024*1024*1024) {
                        $size_cool = sprintf("%.1f", $fsize/(1024*1024));
                        $size_ed = 'Мб';
                } elsif ($fsize >= 1024*1024*1024) {
                        $size_cool = sprintf("%.1f", $fsize/(1024*1024*1024));
                        $size_ed = 'Гб';
                } else {
                        $size_cool = "$fsize.0";
                        $size_ed = 'байт'
                }
 		
		$pathstr = ($fdir eq '/') ? $fdir.'<b>'.$fname.'</b>' : $fdir.'/<b>'.$fname.'</b>';
		$pathstr = $server.$pathstr;
		
		push (@ftable, {'fd' => $fd, 'pathstr' => $pathstr, 'size' => $size_cool, 'size_ed' => $size_ed, 
			'href' => $href, 'time' => $time, 'ind' => $ind});
		$ind++;
	} @$ref;

	my $html = HTML::Template->new(filename => "$Bin/templates/table.tmpl");
	if ($num > 100) {
		my $strnum = sprintf ("%.0f", ceil($num/100) );
		my @pages;
		for (my $i = 1; $i <= $strnum; $i++) {
			if (($i > $page - 10 && $i < $page + 10) || ($i == 1) || ($i == $strnum)) {
				if ($i == $page) {
					push (@pages, {'page' => $i, 'query' => $query, 'ot' => $GET{'ot'}, 
						'do' => $GET{'do'}, 'full' => $GET{'full'}, 'cond' => $cond, 
						'sizesort' => $GET{'sizesort'},  'target' => $GET{'target'} });
				} else {
					push (@pages, {'page' => $i, 'query' => $query, 'ot' => $GET{'ot'}, 
						'do' => $GET{'do'}, 'full' => $GET{'full'}, 'cond' => $cond,
						'sizesort' => $GET{'sizesort'},  'target' => $GET{'target'}, 'print' => 1});
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

our $dbh = DBI->connect( "DBI:mysql:$cfg{'db'}{'dbname'}:$cfg{'db'}{'host'}", $cfg{'db'}{'login'}, $cfg{'db'}{'pass'} ) or die $DBI::errstr;
$dbh->do("SET NAMES 'koi8r'");

html_header();
my $query = $GET{'q'} || '';
if ($query ne '') {
	my $reqtime = localtime;
	my $reqip = $ENV{'REMOTE_ADDR'} || 'HZ';
#	open my $fil, '>>', $cfg{'log'};
#	flock($fil, 2);
#	print $fil "IP: $reqip; TIME: $reqtime; QUERY: $query\n";
#	close $fil;
	$dbh->do(q{ INSERT INTO ftpreq (ftp_req_ip, ftp_req, ftp_req_time) VALUES (?, ?, sysdate()) }, undef, ($reqip, $query)) or die $DBI::errstr;
	$query =~ s/[*%_@]/ /g;
	$query =~ s/\s+/ /;
	$query =~ s/^\s*//;
	$query =~ s/\s*$//;
	my ($flag1, $flag2) = (0, 0);
	if ($cond eq 'AND') {
		$flag1 = grep { length($_) >= 3; } split(' ', $query);
		$flag2 = 1 if $flag1 > 0;
	} else {
		$flag1 = grep { length($_) < 3; } split(' ', $query);
		$flag2 = 1 if $flag1 == 0;
	}
	if ($query ne '' and $flag2 == 1) {
		my $ot = $GET{'ot'} || 0;
		my $do = $GET{'do'} || 1024*1024*1024*100;
		$do = $do <= 1024*1024*1024*100 ? $do : 1024*1024*1024*100;
		if ($ot !~ /^\d+$/ || $do !~ /^\d+$/) {
			print '<br>Неверный формат размера. Должен состоять <b>только</b> из цифр.'."\n";
		} elsif ($ot > $do) {
			print '<br>Минимальный размер должен быть <b>не больше</b> максимального.';
		} else {
			$t0 = [gettimeofday];		
			$printbottom = 1;
			do_sql('query' => $query, 'ot' => $ot, 'do' => $do);
		}
	} else {
		print q{<br>Все допустимые слова (т.е. после вырезания символов '*', '%', '_', '@') запроса меньше 3-х символов в случае поиска по всем словам (или хотя бы одно допустимое слово меньше 3-х символов в случае поиска по любому из слов).}."\n";
	}
}
html_footer();

$dbh->disconnect();
