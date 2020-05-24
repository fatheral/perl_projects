#!/usr/bin/perl -w

use strict;
use CGI::WebOut;
use CGI::WebIn(1);
use DBI;

sub html_header {
	my $html .= "<html><head>\n";
	$html .= qq{<meta http-equiv="Content-Type" content="text/html; charset=koi8-r" />\n};
	$html .= "<title>List of articles | Form to add an article</title>\n";
	$html .= "</head><body>\n";
	$html .= "<h2>Welcome to the simple Editor Web-interface!</h2>\n";
	$html .= "<hr />\n";
        print $html;
								
}

sub html_footer {
	my $html = "</body></html>";
	print $html;
}

sub no_header {
        my $html;
        $html = "<html><head>\n";
        $html .= "<title>No_Header Error</title>";
        $html .= qq(<meta http-equiv="Refresh" content="3; URL=1.pl" />\n);
        $html .= qq{<meta http-equiv="Content-Type" content="text/html; charset=koi8-r" />\n};
        $html .= "</head><body>\n";
        $html .= "You must enter header. Please, try again.<br />\n";
        $html .= qq(<a href="1.pl">Click here, if your browser doesn't support automatic redirect.</a>);
        $html .= "</body></html>";
        print $html;
}
											
sub print_article {
	html_header();
	my $r = $main::dbh->selectall_hashref("SELECT id, header, header||' '||id HID 
					 FROM alextemp", 'HID');
	my $html = '';
	if (! defined %$r) {
		$html .= "There is no articles in the system now.<br>\n";
	} else {
		$html .=  "The list of available articles:<br />";
		$html .=  "<table>\n";
		$html .=  qq(<tr><th>ID</th><th>Header</th></tr>\n);
		map {
			$html .=  "<tr><th><a href=2.pl?id=$$r{$_}{'ID'}>$$r{$_}{'ID'}</a></th><th align=left><a href=2.pl?id=$$r{$_}{'ID'}>$$r{$_}{'HEADER'}</a></th></tr>\n";
		} sort keys %$r;
		$html .= "</table>\n";
	}
	$html .= "<hr />\n";
       	$html .= "<form action=1.pl method=post>\n";
	$html .= "Header of the article (must be filled up):<br />\n";
	$html .= qq(<input type=text size=102 maxlength=100 name="header"><br />\n);
	$html .= "Text of the article:<br />\n";
	$html .= qq(<textarea rows=30 cols=80 name="txt"></textarea><br />\n);
	$html .= qq{<input type=hidden name="action" value="add">\n};
        $html .= qq(<input type=submit name="Enter" value="Submit &nbsp;&raquo;&nbsp;">\n);
       	$html .= qq(</form>\n);
        print $html;
	html_footer();
}

sub add_article {
	my $header = $POST{'header'} || '';
	if ($header eq '') {
		no_header();
	} else {
		my $txt = $POST{'txt'} || '';
		$txt =~ s/\n/<br \/>\n/g;
		$main::dbh->do(qq{ INSERT INTO alextemp
			     (id, header, txt)
			     VALUES
			     (seqalextmp_id.nextval, ?, ?) },
			 undef, ($header, $txt));
		print_article();
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

my $action = $POST{'action'} || '';
if ($action eq 'add') {
	add_article();
} else {
	print_article();
} 
$dbh->disconnect();
