package MBTest;

use strict;

use File::Spec;

BEGIN {
  # In case the test wants to use Test::More or our other bundled
  # modules, make sure they can be loaded.  They'll still do "use
  # Test::More" in the test script.
  my $t_lib = File::Spec->catdir('t', 'bundled');
  push @INC, $t_lib; # Let user's installed version override

  # Make sure none of our tests load the users ~/.modulebuildrc file
  $ENV{MODULEBUILDRC} = 'NONE';
}

use Exporter;
use Test::More;

# We pass everything through to Test::More
use vars qw($VERSION @ISA @EXPORT %EXPORT_TAGS $TODO);
$VERSION = 0.01;
@ISA = qw(Test::More); # Test::More isa Exporter
@EXPORT = @Test::More::EXPORT;
%EXPORT_TAGS = %Test::More::EXPORT_TAGS;

# We have a few extra exports, but Test::More has a special import()
# that won't take extra additions.
my @extra_exports = qw(stdout_of stderr_of slurp find_in_path);
push @EXPORT, @extra_exports;
__PACKAGE__->export(scalar caller, @extra_exports);


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

1;
