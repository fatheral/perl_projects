#!/usr/bin/perl

use strict;
use warnings;

use locale;
use POSIX qw(locale_h ceil);
setlocale(LC_CTYPE,"ru_RU.KOI8-R");

use Encode;
use URI::Escape;
#use CGI::WebOut;
use CGI::WebIn;
use HTML::Template;
use DBI;
use Time::HiRes qw( gettimeofday tv_interval );

use FindBin qw($Bin);
use lib "$Bin/../";

require "cfg.pl";

our %cfg;

####################################

my $t0 = [gettimeofday];;
my $path = 'http://search.bks-tv.ru/cgi/fdir.pl?';
my $html = HTML::Template->new(filename => "$Bin/../templates/search.tmpl");
my $dbh = DBI->connect( "DBI:mysql:$cfg{'db'}{'dbname'}:$cfg{'db'}{'host'}", $cfg{'db'}{'login'}, $cfg{'db'}{'pass'} ) or die $DBI::errstr;
$dbh->do("SET NAMES '".$cfg{'charset_web'}."'");

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
my $page = $GET{'page'} || 1;
$page = 1 if $page !~ /^\d+$/;

my $miss_pages = 10;
my $error;
my $add_count = 1;
my $num_of_req;
my $empty_query = 'Все допустимые слова (т.е. состоящие из символов [0-9a-zA-Zа-яА-Я.-], остальные вырезаются) запроса меньше 3-х символов в случае поиска по всем словам (или хотя бы одно допустимое слово меньше 3-х символов в случае поиска по любому из слов)';

if ($query ne '') {
        my $reqip = $ENV{'REMOTE_ADDR'} || 'HZ';
        $dbh->do(q{ INSERT INTO ftpreq (ftp_req_ip, ftp_req, ftp_req_time) VALUES (?, ?, sysdate()) }, undef, ($reqip, $query)) or die $DBI::errstr;
        my ($flag1, $flag2) = (0, 0);
        if ($cond eq 'AND') {
                $flag1 = grep { length($_) >= 3; } split(' ', $query);
                $flag2 = 1 if $flag1 > 0;
        } 
	else {
                $flag1 = grep { length($_) < 3; } split(' ', $query);
                $flag2 = 1 if $flag1 == 0;
        }
        if ($flag2 == 1) {
                my $ot2 = $GET{'ot'} || 0;
                my $do2 = $GET{'do'} || 1024*1024*1024*100;
                $do2 = ($do2 <= 1024*1024*1024*100) ? $do2 : 1024*1024*1024*100;
                if ($ot2 > $do2) {
			$error = 'Минимальный размер файла должен быть <i>не больше</i> максимального.';
                } 
		else {
                        do_sql('ot2' => $ot2, 'do2' => $do2);
                }
        } 
	else {
		$error = $empty_query;
        }
}
else {
	$error = $empty_query;
	$add_count = 0;
}

if ($add_count) {
	($num_of_req) = $dbh->selectrow_array("SELECT ftp_count FROM ftpcount");
	$num_of_req++;
	$dbh->do("UPDATE ftpcount SET ftp_count = ?", undef, $num_of_req);
}
else {
	($num_of_req) = $dbh->selectrow_array("SELECT ftp_count FROM ftpcount");
}
$dbh->disconnect();
my $t1 = sprintf("%.2f", tv_interval($t0));
params2tmpl();

print "Content-Type: text/html; charset=koi8-r\n\n";
print $html->output();

sub params2tmpl {
	$html->param(	'query' => $query, 
			'ot' => $ot, 
			'do' => $do, 
			'cond' => $cond, 
			'target' => $target, 
			'full' => $full, 
			'sizesort' => $sizesort	);
	$html->param('sek' => $t1);
	$html->param('error' => $error) if $error;
	$html->param('otchet' => scalar(localtime));
	$html->param('numreq' => $num_of_req);
}

sub do_sql {
	my %params = @_;
	my $ot2 = 1024*$params{'ot2'};
	my $do2 = 1024*$params{'do2'};
	my @list = split(' ', $query);
	my $s;
	map {
		unless ($full) {
			$s .= qq{$cond ftp_name LIKE CONCAT('%', ?, '%') };
		} else {
			$s .= qq{$cond CONCAT(IF(ftp_dir = '/', '', ftp_dir), '/', ftp_name) LIKE CONCAT('%', ?, '%') };
		}
	} @list;
	$s =~ s/^$cond /(/;
	$s .= q{AND ftp_name IS NOT NULL) AND (ftp_size BETWEEN ? AND ?) };
	my $sql = q{ SELECT ftp_dir, ftp_name, ftp_isdir, ftp_size, ftp_server, DATE_FORMAT( ftp_indtime, '%Y-%m-%d' ), ftp_file_id, ftpsearch.ftp_server_id 
		     FROM ftpsearch, ftpserver
		     WHERE ftpsearch.ftp_server_id = ftpserver.ftp_server_id AND }.$s.$ext_spec{$target}." ORDER BY ";
	$sql .= "ftp_size DESC, " if $sizesort;
	$sql .= "ftp_server, ftp_dir, ftp_name";
	my $sql2 = qq{ SELECT COUNT(*) 
		       FROM ftpsearch, ftpserver
		       WHERE ftpsearch.ftp_server_id = ftpserver.ftp_server_id AND }.$s.$ext_spec{$target};
	my ($num) = $dbh->selectrow_array($sql2, undef, (@list, $ot2, $do2));
	my $ref;
	if ($num == 0) {
		$error = 'Нет строк, удовлетворяющих Вашему запросу';
	} elsif ($num <= 100) {
		$ref = $dbh->selectall_arrayref($sql, undef, (@list, $ot2, $do2));
		print_table('ref' => $ref, 'num' => $num);
	} else {
		my $firstind = 100*($page - 1);
		$sql = $sql." LIMIT $firstind, 100";
		$ref = $dbh->selectall_arrayref($sql, undef, (@list, $ot2, $do2));
		print_table('ref' => $ref, 'num' => $num);
	}
}

sub print_table {
	my %params = @_;
	my ($ref, $num) = ($params{'ref'}, $params{'num'});
	my @ftable;
	my ($pathstr, $fd, $size_cool, $href, $size_ed);
	my $ind = 100*($page - 1) + 1;
	foreach (@$ref) {
		my ($fdir, $fname, $flag, $fsize, $server, $time, $ftp_id, $serv_id) = @$_;
		if ($flag eq 'd') {
			$fd = 'class="fd"';
			$href = $path.'dir='.$ftp_id.'&amp;serv='.$serv_id;
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
 		
		$pathstr = ($fdir eq '/') ? $fdir.'<b>'.$fname.'</b>' : $fdir.'/<b>'.$fname.'</b>';
		$pathstr = 'ftp://'.$server.$pathstr;
		
		push (@ftable, {'fd' => $fd, 'pathstr' => $pathstr, 'size' => $size_cool, 'size_ed' => $size_ed, 
			'href' => $href, 'time' => $time, 'ind' => $ind});
		$ind++;
	}

	if ($num > 100) {
		my $strnum = sprintf ("%.0f", ceil($num/100) );
		my @pages;
		
		for (my $i = 1; $i <= $strnum; $i++) {
			if (($i > $page - $miss_pages && $i < $page + $miss_pages) || ($i == 1) || ($i == $strnum)) {
				if ($i == $page) {
					push (@pages, {	'page' => $i	});
				} else {
					push (@pages, {	'page' => $i, 
							'query' => $query, 
							'ot' => $ot,
							'do' => $do, 
							'full' => $full, 
							'cond' => $cond,
							'sizesort' => $sizesort,  
							'target' => $target,
							});
				}
				if (($i == 1 && $page - $miss_pages > 1)
				  || ($i == $page + $miss_pages - 1 && $page + $miss_pages < $strnum)) {
					push (@pages, { 'page' => '...'	});
				}
					
			}
		}
		$html->param('pages' => \@pages, 'strnum' => $strnum, 'page' => $page);
	}
	$html->param('ftable' => \@ftable, 'num' => $num);
}
