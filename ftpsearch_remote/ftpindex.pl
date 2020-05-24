#!/usr/bin/perl 

use strict;
use warnings;
use Net::FTP;
use Encode;
use File::Basename;
use DBI;
use FindBin qw($Bin);
use lib "$Bin";

require "cfg.pl";

our %cfg;

my $log = $cfg{'ind_log'};

my $dbh = DBI->connect( "DBI:mysql:$cfg{'db'}{'dbname'}:$cfg{'db'}{'host'}", $cfg{'db'}{'login'}, $cfg{'db'}{'pass'} ) or die $DBI::errstr;
$dbh->do("SET NAMES '".$cfg{'charset_db'}."'") or die $DBI::errstr;

$dbh->do(q{ ALTER TABLE ftpsearch DROP INDEX ftp_parent_id }) or die $DBI::errstr;
# Сканируем доступные фтп-сервера
foreach (keys %{ $cfg{'servers'} }) {
	my $serv = $_;
	my $serv_id = $cfg{'servers'}{$serv}{'id'};
	my ($servname) = $dbh->selectrow_array(q{ SELECT ftp_server FROM ftpserver WHERE ftp_server_id = ? }, undef, $serv_id) or die $DBI::errstr;
	my $flag = 1;

	my $ftp = Net::FTP->new($servname, Debug => 0, Timeout => 60) or $flag = 0;
	unless ($flag) {
		print "Cannot connect to $servname: $@\n";
	} else {
		$ftp->login("anonymous", 'anonymous@anon.ru') or $flag = 0;
		unless ($flag) {
			print "Cannot login ".$ftp->message."\n";
			$ftp->close();
		} else {
			print "Server $servname is on\n";
			print "Wait for while scanning $servname...\n";

			my $t = time();

			$dbh->do("DELETE FROM ftpsearch WHERE ftp_server_id = ?", undef, $serv_id);

			my @excl_dirs = @{ $cfg{'servers'}{$serv}{'excluded_dirs'} };
			my $n = 1;
			$dbh->do("INSERT INTO ftpsearch
				  (ftp_file_id, ftp_dir, ftp_name, ftp_server_id, ftp_indtime)
				  VALUES (?, '---===ALL===---', NULL, ?, sysdate() )",
				  undef, ($n, $serv_id) ) or die $DBI::errstr;
			my @dirs = map { [$_, [$n]] } @{ $cfg{'servers'}{$serv}{'included_dirs'} };

			open my $fh, '>>', $log;
			my $tim = localtime();
			print $fh "\n---=== Scanning $servname ===---\n";
			print $fh "Start time: $tim\n";
			print $fh "Included dirs: @{ $cfg{'servers'}{$serv}{'included_dirs'} }\n";
			print $fh "Excluded dirs: @excl_dirs\n";
			close($fh);
			
			while (@dirs > 0) {
				my $refdir = shift (@dirs); 
				my $dir = $refdir->[0];
				my @prevdirs = @{ $refdir->[1] };
				my $count = grep { $dir =~ /^\Q$_\E/ } @excl_dirs;
				next if $count;
				my $dircount;
				unless ($dir eq "/") {
					my $dirname = basename($dir);
					my $dirdir = dirname($dir);
					$n++;
					$dircount = $n;
					my ($encdir, $encname) = ( encode($cfg{'charset_db'}, decode($cfg{'charset_ftp'}, $dirdir)), encode($cfg{'charset_db'}, decode($cfg{'charset_ftp'}, $dirname)) );
					$dbh->do("INSERT INTO ftpsearch
						  (ftp_file_id, ftp_parent_id, ftp_dir, ftp_name, ftp_server_id, ftp_indtime)
						  VALUES (?, ?, ?, ?, ?, sysdate() )", 
						  undef, ($n, $prevdirs[-1], $encdir, $encname, $serv_id) ) or die $DBI::errstr;
				} 

				push (@prevdirs, $dircount) if $dir ne "/";
				
				$ftp->cwd($dir);
				my @all = $ftp->dir();
				foreach (@all) {
					if ($_ =~ /^(\S)\S{9}\s+\d+\s+\S+\s+\S+\s+(\d+)\s+\S+\s+\d+\s+\S+\s+(\S+.*)$/) {
						my ($isdir, $size, $name) = ($1, $2, $3);
						my $f;
						unless ($dir eq "/") {
							$f = $dir."/".$name;
						} else {
							$f = $dir.$name;
						}
						if ( $name !~ /\?/ && $isdir eq 'd') {
							push (@dirs, [ $f, [ @prevdirs ] ] );
						} elsif ($name !~ /\?/) { 
							$n++;
							my ($encdir, $encname) = ( encode($cfg{'charset_db'}, decode($cfg{'charset_ftp'}, $dir)), encode($cfg{'charset_db'}, decode($cfg{'charset_ftp'}, $name)) );
							$dbh->do("INSERT INTO ftpsearch
								  (ftp_file_id, ftp_parent_id, ftp_dir, ftp_name, ftp_isdir, ftp_size, ftp_server_id, ftp_indtime)
								  VALUES (?, ?, ?, ?, ?, ?, ?, sysdate() )",
								  undef, ($n, $prevdirs[-1], $encdir, $encname, 'f', $size, $serv_id) ) or die $DBI::errstr;
							foreach (@prevdirs) {
								$dbh->do("UPDATE ftpsearch
									  SET ftp_size = ftp_size + ?
									  WHERE ftp_file_id = ? 
									    AND ftp_server_id = ?",
									  undef, ($size, $_, $serv_id) );
							}
						}
					}
				}
			}

			$ftp->quit();
			$t = time() - $t;
			my $sec = $t % 60;
			my $min = ($t - $sec)/60;
			print "Scan of $servname complete. It took $min minutes, $sec seconds.\n";

			open $fh, '>>', $log;
			$tim = localtime();
			print $fh "Finish time: $tim\n";
			print $fh "Scan completed in $min minutes, $sec seconds\n";
			print $fh "$n files were scanned\n";
			print $fh "---=== Done ===---\n";
			close ($fh);

		}
	}
}

$dbh->do(q{ ALTER TABLE ftpsearch ADD INDEX ftp_parent_id (ftp_parent_id, ftp_server_id) }) or die $DBI::errstr;

$dbh->do(q{ TRUNCATE TABLE ftpcumreq }) or die $DBI::errstr;
$dbh->do(q{     INSERT INTO ftpcumreq (ftp_req, ftp_req_cnt)
                SELECT ftp_req, count(*) AS ftp_req_cnt
                FROM ftpreq
                GROUP BY ftp_req
                ORDER BY ftp_req_cnt DESC }) or die $DBI::errstr;
		
open my $fh, '>>', $log;
print $fh "~~~ Statistics is uptodate ~~~\n";
close $fh;

$dbh->disconnect();

