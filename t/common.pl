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

sub skip_subtest {
  my $msg = @_ ? shift() : '(no reason given)';
  skip "skip $msg", 1;
}

sub save_handle {
  my ($handle, $subr) = @_;
  my $outfile = 'save_out';

  local *SAVEOUT;
  open SAVEOUT, ">&" . fileno($handle) or die "Can't save output handle: $!";
  open $handle, "> $outfile" or die "Can't create $outfile: $!";

  eval {$subr->()};
  open $handle, ">&SAVEOUT" or die "Can't restore output: $!";

  my $ret = slurp($outfile);
  1 while unlink $outfile;
  return $ret;
}

sub stdout_of { save_handle(\*STDOUT, @_) }
sub stderr_of { save_handle(\*STDERR, @_) }

sub slurp {
  my $fh = IO::File->new($_[0]) or die "Can't open $_[0]: $!";
  local $/;
  return scalar <$fh>;
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

sub array_eq { # like Test::More::eq_array
  my( $a1, $a2 ) = @_;
  return 0 unless @$a1 == @$a2;

  for my $i ( 0..$#{$a1} ) {
    return 0 unless $a1->[$i] eq $a2->[$i];
  }

  return 1;
}

1;
