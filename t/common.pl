use strict;
use Config;

sub have_module {
  my $module = shift;
  return eval "use $module; 1";
}

sub need_module {
  my $module = shift;
  skip_test("$module not installed") unless have_module($module);
}

sub skip_test {
  my $msg = @_ ? shift() : '';
  print "1..0 # Skipped: $msg\n";
  exit;
}

sub stdout_of {
  my $subr = shift;
  my $outfile = 'save_out';

  local *SAVEOUT;
  open SAVEOUT, ">&STDOUT" or die "Can't save STDOUT handle: $!";
  open STDOUT, "> $outfile" or die "Can't create $outfile: $!";

  eval {$subr->()};
  open STDOUT, ">&SAVEOUT" or die "Can't restore STDOUT: $!";

  return slurp($outfile);
}

sub stderr_of {
  my $subr = shift;
  my $outfile = 'save_err';

  local *SAVEERR;
  open SAVEERR, ">&STDERR" or die "Can't save STDERR handle: $!";
  open STDERR, "> $outfile" or die "Can't create $outfile: $!";

  eval {$subr->()};
  open STDERR, ">&SAVEERR" or die "Can't restore STDERR: $!";

  return slurp($outfile);
}

sub slurp {
  my $fh = IO::File->new($_[0]) or die "Can't open $_[0]: $!";
  local $/;
  return <$fh>;
}

sub find_in_path {
  my $thing = shift;
  
  my @path = split $Config{path_sep}, $ENV{PATH};
  my @exe_ext = $^O eq 'MSWin32' ? ('', # may have extension already
    split($Config{path_sep}, $ENV{PATHEXT} || '.com;.exe;.bat')) :
    ('');
  foreach (@path) {
    my $fullpath = File::Spec->catfile($_, $thing);
    foreach my $ext ( @exe_ext ) {
      return "$fullpath$ext" if -e "$fullpath$ext";
    }
  }
  return;
}

1;
