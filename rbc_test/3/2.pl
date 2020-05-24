#!/usr/bin/perl -w

use strict;
use CGI::WebOut;
use CGI::WebIn(1);
use DBI;

sub html_header {
	my $title = $_[0];
	my $html .= "<html><head>\n";
	$html .= qq{<meta http-equiv="Content-Type" content="text/html; charset=koi8-r" />\n};
	$html .= "<title>Article | $title</title>\n";
	$html .= "</head><body>\n";
	$html .= "<a href=1.pl>Switch to the article list and add form</a><br />\n";
	$html .= "<hr />\n";
        print $html;
								
}

sub html_footer {
	my $html = "</body></html>";
	print $html;
}

sub some_error {
        my $html;
        $html = "<html><head>\n";
        $html .= "<title>No_Header Error</title>";
        $html .= qq(<meta http-equiv="Refresh" content="3; URL=1.pl" />\n);
        $html .= qq{<meta http-equiv="Content-Type" content="text/html; charset=koi8-r" />\n};
        $html .= "</head><body>\n";
        $html .= "There some error occurs (wrong id of article or some other mistake). You have to re-choose the article.<br />\n";
        $html .= qq(<a href="1.pl">Click here, if your browser doesn't support automatic redirect.</a>);
        $html .= "</body></html>";
        print $html;
}
											
sub print_article {
	my $id = $_[0];
	my $r = $main::dbh->selectrow_arrayref("SELECT header, txt 
					 FROM alextemp
					 WHERE id = ?",
					 undef, $id);
	my $html = '';
	if (! defined @$r) {
		some_error();
	} else {
		my $header = $r->[0];
		my $txt = $r->[1];
		#$txt =~ s#\r#<br />\n#g;
		html_header($r->[0]);
		$html .= "<h3>".$r->[0]."</h3>\n";
		$html .= $r->[1];
        	print $html;
		html_footer();
	}
}

###############################################################################################################################
######################################################## Main part ############################################################
###############################################################################################################################

our $dbh;

$ENV{ORACLE_HOME} = '/correct_path';
$ENV{NLS_LANG} = 'AMERICAN_CIS.CL8KOI8R'; #CL8MSWIN1251 CL8KOI8R
$dbh = DBI->connect( 'dbi:Oracle:host=HOST;sid=DB', 'user', 'password', {RaiseError => 1, AutoCommit => 0} ) 
  or die $DBI::errstr;
$dbh->{LongReadLen} = 512 * 1024;

my $id = $GET{'id'} || '';
if ($id =~ /^\d+$/) {
	print_article($id);
} else {
	some_error();
} 
$dbh->disconnect();
