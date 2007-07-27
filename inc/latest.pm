package latest;

use strict;
use File::Spec;
use IO::File;

my $mypath;


sub import {
  my ($pack, $mod, @args) = @_;
  my $file = $pack->_mod2path($mod);

  if ($INC{$file}) {
    # Already loaded
    return $pack->_load($mod, @args);
  }

  # A bundled copy must be present
  my ($bundled, $bundled_dir) = $pack->_search_bundled($file)
    or die "No bundled copy of $mod found";
  
  my $from_inc = $pack->_search_INC($file);
  unless ($from_inc) {
    # Only bundled is available
    local @INC = ($bundled_dir, @INC);
    return $pack->_load($mod, @args);
  }

  if (_version($from_inc) > _version($bundled)) {
    # Ignore the bundled copy
    return $pack->_load($mod, @args);
  }

  # Load the bundled copy
  local @INC = ($bundled_dir, @INC);
  return $pack->_load($mod, @args);
}

sub _version {
  # TODO: So far this only handles the extremely easy cases
  my ($file) = @_;
  my $fh = IO::File->new($file) or die "Can't read $file: $!";
  while (<$fh>) {
    return (eval $2) if /^\s*\$VERSION\s*=\s*(['"]?)([\d._]+)\1/;
  }
  return;
}

sub _load {
  my ($self, $mod, @args) = @_;
  eval "require $mod";
  die $@ if $@;
  $mod->import(@args);
  return;
}

sub _search_bundled {
  my ($self, $file) = @_;

  $mypath ||= (File::Spec->splitpath( $INC{ __PACKAGE__ . '.pm' } ))[1];

  local *DH;   # Maintain 5.005 compatibility
  opendir DH, $mypath or die "Can't open directory $mypath: $!";

  while (defined(my $e = readdir DH)) {
    next unless $e =~ /^inc_/;
    my $try = File::Spec->catfile($mypath, $e, $file);
    
    return($try, File::Spec->catdir($mypath, $e)) if -e $try;
  }
  return;
}

sub _search_INC {
  # TODO: doesn't handle coderefs or arrayrefs or objects in @INC, but
  # it probably should
  my ($self, $file) = @_;

  foreach my $dir (@INC) {
    my $try = File::Spec->catfile($dir, $file);
    return $try if -e $try;
  }

  return;
}

sub _mod2path {
  my ($self, $mod) = @_;
  my @parts = split /::/, $mod;
  $parts[-1] .= '.pm';
  return $parts[0] if @parts == 1;
  return File::Spec->catfile(@parts);
}

1;
