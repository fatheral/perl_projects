#!/usr/bin/perl 

use strict;
use warnings;
#use Encode;
use DBI;

use FindBin qw($Bin);
use lib "$Bin/include";

require "cfg.pl";

our %cfg;

open my $fil, '>>', $cfg{'log'};

my $t = time();
my $time = localtime;

my $serv_id = $cfg{'id'};

my $dbh = DBI->connect( "DBI:mysql:$cfg{'db'}{'dbname'}:$cfg{'db'}{'host'}", $cfg{'db'}{'login'}, $cfg{'db'}{'pass'} ) or die $DBI::errstr;
$dbh->do("SET NAMES 'koi8r'");

my ($server) = $dbh->selectrow_array(q{ SELECT ftp_server FROM ftpserver WHERE ftp_server_id = ? }, undef, $serv_id) or die $DBI::errstr;

$dbh->do(q{ ALTER TABLE ftpsearch DROP INDEX ftp_parent_id }) or die $DBI::errstr;
$dbh->do(q{ DELETE FROM ftpsearch WHERE ftp_server_id = ? }, undef, $serv_id) or die $DBI::errstr;

print "---=== Scan start: $time ===---\n";
print $fil "\n---=== Scan start: $time ===---\n";

my $n = 1;
$dbh->do(q{ INSERT INTO ftpsearch
		   (ftp_file_id, ftp_dir, ftp_server_id, ftp_indtime)
	    VALUES (?, '---===ALL===---', ?, sysdate() ) }, 
	    undef, ($n, $serv_id)) or die $DBI::errstr;

my @dirs = @{ $cfg{'dirs'}{'incl_dir'} };
my @rels = ();
push (@rels, [ $n ]) for 0..$#dirs;
my @excl_dirs = @{ $cfg{'dirs'}{'excl_dir'} };

print "Included dirs: @dirs\n";
print $fil "Included dirs: @dirs\n";
print "Excluded dirs: @excl_dirs\n";
print $fil "Excluded dirs: @excl_dirs\n";
print "Wait for while scanning $server server...\n";

while (@dirs > 0) {
	my $dir = shift (@dirs);
	my @currels = @{ shift (@rels) };
	my $flag = grep { $dir =~ /^\Q$_\E/ } @excl_dirs;
	next if $flag;

	opendir (D, $dir);
	my @curlist = grep { $_ ne '.' && $_ ne '..' } readdir(D);
	closedir(D);

	foreach (@curlist) {
		my $name = $_;
		my $f = $dir."/".$name;
#		my ($encdir, $encname) = (encode("utf8", decode("koi8-r", length($dir) > 4 ? substr($dir, 4) : '/')), encode("utf8", decode("koi8-r", $name )));
		my ($encdir, $encname) = (length($dir) > 4 ? substr($dir, 4) : '/', $name );
		if (-d $f && $name !~ /\?/) {
			push (@dirs, $f);
			$n++;
			$dbh->do("INSERT INTO ftpsearch
					 (ftp_file_id, ftp_parent_id, ftp_dir, ftp_name, ftp_server_id, ftp_indtime)
				  VALUES (?, ?, ?, ?, ?, sysdate() )",  undef, ($n, $currels[-1], $encdir, $encname, $serv_id)) or die $DBI::errstr;
			push (@rels, [@currels, $n]);
		} elsif ($name !~ /\?/) {
			my $size = (stat($f))[7] || 0;
			$n++;
			$dbh->do("INSERT INTO ftpsearch
					 (ftp_file_id, ftp_parent_id, ftp_dir, ftp_name, ftp_isdir, ftp_size, ftp_server_id, ftp_indtime)
				  VALUES (?, ?, ?, ?, 'f', ?, ?, sysdate() )",  undef, ($n, $currels[-1], $encdir, $encname, $size, $serv_id)) or die $DBI::errstr;
			foreach (@currels) {
				$dbh->do("UPDATE ftpsearch
					  SET ftp_size = ftp_size + ?
					  WHERE ftp_file_id = ?
					    AND ftp_server_id = ?", undef, ($size, $_, $serv_id)) or die $DBI::errstr;
			}
		}
	}
}

$dbh->do(q{ ALTER TABLE ftpsearch ADD INDEX ftp_parent_id (ftp_parent_id, ftp_server_id) }) or die $DBI::errstr;

$dbh->disconnect();

$t = time() - $t;
$time = localtime;
my $sec = $t % 60;
my $min = ($t - $sec)/60;
print "$n files were scanned.\n";
print $fil "$n files were scanned.\n";
print "Scan of $server server complete. It took $min minutes, $sec seconds.\n";
print $fil "Time of scan $server server: $min minutes, $sec seconds.\n";
print "---=== Scan finish: $time ===---\n";
print $fil "---=== Scan finish: $time ===---\n";

close $fil;
