use strict;
use Config;

use lib 't/lib';

BEGIN {
  # In case the test wants to use Test::More or our other bundled
  # modules, make sure they can be loaded.  They'll still do "use
  # Test::More" in the test script.
  my $t_lib = File::Spec->catdir('t', 'bundled');
  push @INC, $t_lib; # Let user's installed version override

  # Make sure none of our tests load the users ~/.modulebuildrc file
  $ENV{MODULEBUILDRC} = 'NONE';
}


sub have_module {
  my $module = shift;
  return eval "use $module; 1";
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


# A hash of all Config.pm settings related to installing
# manpages with values set to an empty string.
sub manpage_reset {
  return (
    installman1dir => '',
    installman3dir => '',
    installsiteman1dir => '',
    installsiteman3dir => '',
    installvendorman1dir => '',
    installvendorman3dir => '',
  );
}

# A hash of all Config.pm settings related to installing
# html documents with values set to an empty string.
sub html_reset {
  return (
    installhtmldir => '',
    installhtml1dir => '',
    installhtml3dir => '',
    installsitehtml1dir => '',
    installsitehtml3dir => '',
    installvendorhtml1dir => '',
    installvendorhtml3dir => '',
  );
}

1;
