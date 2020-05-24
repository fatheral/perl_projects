#!/usr/bin/perl

use strict;
use warnings;

use CGI::WebOut;
use CGI::WebIn(1);
use HTML::Template;
use FindBin qw($Bin);

my $str; # = '56-5/(2-(1+1))';
my $n;

my $doplus  = sub { return $_[0] + $_[1] };
my $dominus = sub { return $_[0] - $_[1] };
my $dodot = sub { return $_[0]*$_[1] };
my $dodiv = sub { return $_[0]/$_[1] };


my %oper = ( '+' => $doplus, 
	     '-' => $dominus,
	     '*' => $dodot,
	     '/' => $dodiv,
);

sub plainfunc {
	my $s = $_[0];
	$s =~ s/^-/~/ if $s =~ /^-/;
	return (0, 'Пустое выражение (возможно, в скобках)', '') if $s =~ /^~?\s*$/;
	my ($op1, $op2, $znak, $rr);
	$s = " $s ";
	while ($s =~ /[^~\d](~?\d+\.?\d*)([\/\*])(~?\d+\.?\d*)[^\d]/) {
		$op1 = $1;
		$op2 = $3;
		$znak = $2;
		$op1 =~ s/^~/-/;
		$op2 =~ s/^~/-/;
		if ($znak eq '/' &&  $op2 == 0) {
			return (0, 'Деление на нуль!', '');
		}
		$rr = $oper{$znak}->($op1, $op2);
		$n++;
		print "$n) $op1 $znak $op2 = $rr<br />\n";
		$rr =~ s/^-/~/ if $rr =~ /^-/;
		$s =~ s/([^~\d])~?\d+\.?\d*[\/\*]~?\d+\.?\d*([^\d])/$1$rr$2/;
	}
        while ($s =~ /[^~\d](~?\d+\.?\d*)([\+\-])(~?\d+\.?\d*)[^\d]/) {
                $op1 = $1;
                $op2 = $3;
                $znak = $2;
                $op1 =~ s/^~/-/;
                $op2 =~ s/^~/-/;
                $rr = $oper{$znak}->($op1, $op2);
		$n++;
                print "$n) $op1 $znak $op2 = $rr<br />\n";
                $rr =~ s/^-/~/ if $rr =~ /^-/;
                $s =~ s/([^~\d])~?\d+\.?\d*[\+\-]~?\d+\.?\d*([^\d])/$1$rr$2/;
        }
	
	$s =~ s/^ (.*) $/$1/;
	$s =~ s/^-/~/ if $s =~ /^-/;
	return (1, '', $s);
}

sub main {
	my ($l, $r) = (0, 0);
	return 'Не должно идти два знака действий подряд' if $str =~ /[+\-*\/][+\-*\/]/;
	return 'Точка должна хотя бы с одной стороны окаймляться цифрой' if $str =~ /[^\d]\.[^\d]/;
	
	my @str = split('', $str);
	for (@str) {
		$l++ if $_ eq '(';
		$r++ if $_ eq ')';
		return 'Число открывающих скобок всегда должно быть не меньше закрывающих' if $l < $r;
	}
	return 'Число открывающих больше числа закрывающих' if $l > $r;
	
	my $s = $str;
	my ($err, $mes, $res);
	
	while ($s =~ /\(([^()]+)\)/) {
		print "<i>Разбор скобки:</i> $1<br />\n";
		($err, $mes, $res) = plainfunc($1);
		print "<i>Конец разбора скобки</i><br />\n";
		return $mes if $err == 0;
		$s =~ s/\([^()]+\)/$res/;
	}

	($err, $mes, $res) = plainfunc($s);
	return $mes if $err == 0;
	return $res;

}

sub dostr {
	$str =~s/[^()\d.+\-*\/]//g;
        $str = " $str";
        $str =~ s/(\d\.)([^\d])/$1 0$2/g;
        $str =~ s/([^\d])(\.\d)/$1 0$2/g;
        $str =~ s/\s//g;
	$str =~ s/\)\(/)*(/g;
	$str =~ s/(\d)\(/$1*(/g;
	$str =~ s/^[+*\/]//;
	$str =~ s/\([+*\/]/(/g;
	$str =~ s/[+\-*\/]\)/)/g;
	$str =~ s/[+\-*\/]$//;
}

sub html_header {
	my $html = HTML::Template->new(filename => "$Bin/calc.tmpl");
	print $html->output;
}

sub html_footer {
	my $html = "</body></html>";
	print $html;
}

html_header();
$str = $GET{'q'} || '';
if ($str ne '') {
	dostr();
	print "<b>Исходная строка:</b> $str<br />\n";
	my $f = main();
	$f =~ s/^~/-/ if $f =~ /^~/;
	print "<b>Результат:</b> $f<br />\n";
	
}
html_footer();
