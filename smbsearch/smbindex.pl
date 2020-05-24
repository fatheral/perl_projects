#!/usr/bin/perl 

use strict;
use warnings;
use File::Basename;
use Filesys::SmbClient;
use Net::Ping;
use DBI;
use FindBin qw($Bin);
use lib "$Bin/include";

#####################################

sub ddir {
	my $str = $_[0];
	$str =~ s#^(.*)/[^/]+$#$1#;
	$str = $str || "/";
	return $str;
}

sub dname {
        my $str = $_[0];
        $str =~ s#^.*/([^/]+)$#$1#;
        return $str;
}

##################################33#

require "cfg.pl";

our %cfg;

# Настройки для оракловской базы данных
$ENV{ORACLE_HOME} = $cfg{'oracle'}{'home'};
$ENV{NLS_LANG} = $cfg{'oracle'}{'lang_ind'};
my $dbh = DBI->connect( "dbi:Oracle:host=$cfg{'db'}{'host'};sid=$cfg{'db'}{'sid'}", $cfg{'db'}{'login'}, $cfg{'db'}{'pass'}, {RaiseError => 1, AutoCommit => 0} ) or die $DBI::errstr;

my $smb = new Filesys::SmbClient(username  => "guest");
# Сканируем доступные фтп-сервера
map {
	my $host = $_;
	my $flag = 0;

	my $p = Net::Ping->new();
	$flag = 1 if $p->ping($host);
	$p->close();
	
	unless ($flag) {
		print "$host is unreachable.\n";
	} else {
		print "$host is on.\n";
		print "Wait for while scanning $host...\n";

		my $t = time();

		$dbh->do("DELETE FROM smbsearch WHERE host = ?", undef, $host);

		my $fd = $smb->opendir("smb://$host");
		my @dirs = map { '/'.$_->[1] } grep { $_->[0] == SMBC_FILE_SHARE && $_->[1] !~ /\$$/ && $_->[1] ne '.' && $_->[1] ne '..' } $smb->readdir_struct($fd);

		while (@dirs > 0) {
			my $dir = shift (@dirs); 
			my ($dirdir, $dirname) = (dirname($dir), basename($dir));
                        $dbh->do("INSERT INTO smbsearch
				  (sdir, sname, flag, ssize, host, time)
				  VALUES (?, ?, ?, ?, ?, sysdate)",
				 undef, ($dirdir, $dirname, 'd', 0, $host) );
			print "smb://$host$dir\n";
			my $ex = 0;
			$fd = $smb->opendir("smb://$host$dir") or $ex = 1;
			next if $ex;
			my @all = grep { $_->[1] !~ /\$$/ && $_->[1] ne '.' && $_->[1] ne '..' } $smb->readdir_struct($fd);

			map {
				my $isdir = $_->[0];
				my $name = $_->[1];
				my $f = $dir."/".$name;
				
				if ($isdir == SMBC_DIR && $name !~ /\?/) {
					push (@dirs, $f);
				} elsif ($isdir == SMBC_FILE && $name !~ /\?/) { 
					my $size = ($smb->stat("smb://$host$f"))[7] || 0;
					$dbh->do("INSERT INTO smbsearch
						  (sdir, sname, flag, ssize, host, time)
						  VALUES (?, ?, ?, ?, ?, sysdate)",
						 undef, ($dir, $name, 'f', $size, $host) );
					$dbh->do("UPDATE smbsearch
						  SET ssize = ssize + ?
						  WHERE flag = 'd'
						  	AND ? LIKE decode(sdir, '/', '', sdir)||'/'||sname||'%'
							AND host = ?",
						 undef, ($size, $dir, $host) );
				}
			} @all;
		}
		$t = time() - $t;
		my $sec = $t % 60;
		my $min = ($t - $sec)/60;
		print "Scan of $host complete. It took $min minutes, $sec seconds.\n";
	}
} @{ $cfg{'host'} };

$dbh->disconnect();
