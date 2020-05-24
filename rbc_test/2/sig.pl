#!/usr/bin/perl -w
$| = 1;
my $parent = $$;  # PID родительского процесса
my $pid = fork(); # 'разветвить' текущий процесс
# fork вернет PID потомка в процессе-предке и 0 в потомке
die "fork не отработал: $!" unless defined $pid;
if ($pid) { # ---------- родительский процесс ----------A
   print "1";
   kill HUP, $pid;
   $SIG{HUP} = sub { ### обработчик сигнала ###
        print "1";
        kill HUP, $pid;
   };
   while (1) { }
}
unless ($pid) { # ---------- дочерний процесс ----------
   $SIG{HUP} = sub { ### обработчик сигнала ###
      print "2";
      kill HUP, $parent;
   };                ### конец обработчика сигнала ###
   while (1) { }
}
