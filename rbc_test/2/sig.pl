#!/usr/bin/perl -w
$| = 1;
my $parent = $$;  # PID ������������� ��������
my $pid = fork(); # '����������' ������� �������
# fork ������ PID ������� � ��������-������ � 0 � �������
die "fork �� ���������: $!" unless defined $pid;
if ($pid) { # ---------- ������������ ������� ----------A
   print "1";
   kill HUP, $pid;
   $SIG{HUP} = sub { ### ���������� ������� ###
        print "1";
        kill HUP, $pid;
   };
   while (1) { }
}
unless ($pid) { # ---------- �������� ������� ----------
   $SIG{HUP} = sub { ### ���������� ������� ###
      print "2";
      kill HUP, $parent;
   };                ### ����� ����������� ������� ###
   while (1) { }
}
