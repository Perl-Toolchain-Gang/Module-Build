package inc::latest;
use strict;
use warnings;

use Carp;
use File::Spec;
use File::Basename;
use File::Path;
use IO::File;

sub import {
  my ($package, $mod, @args) = @_;
  return unless(defined $mod);

  my $inc_path = './inc/latest.pm';
  if(-e $inc_path) {
    # delete our methods
    delete $inc::latest::{$_} for(keys %inc::latest::);
    # load the bundled module
    require $inc_path;
    my $import = inc::latest->can('import');
    goto $import;
  }

  # author mode - just load the modules
  $package->load_module($mod, @args);
}

my @loaded_modules;
sub loaded_modules {@loaded_modules}

sub load_module {
  my $package = shift;
  my ($mod, @args) = @_;

  push(@loaded_modules, $mod);
  (my $pm = $mod) =~ s#::#/#g;
  $pm .= '.pm';
  require($pm);
  if(@args and my $import = $mod->can('import')) {
    goto $import;
  }
}

sub write {
  my $package = shift;
  my ($where) = @_;

  my $dir = dirname( $where );
  warn "should really be writing in inc/" unless $dir =~ /inc$/;
  mkpath $dir;
  my $fh = IO::File->new( $where, "w" );
  print {$fh} do {local $/; <DATA>};
}

1;

__DATA__
package inc::latest;

use strict;
use File::Spec;
use IO::File;

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
    unshift(@INC, $bundled_dir);
    return $pack->_load($mod, @args);
  }

  if (_version($from_inc) > _version($bundled)) {
    # Ignore the bundled copy
    return $pack->_load($mod, @args);
  }

  # Load the bundled copy
  unshift(@INC, $bundled_dir);
  return $pack->_load($mod, @args);
}

sub _version {
  require ExtUtils::MakeMaker;
  return ExtUtils::MM->parse_version(shift);
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

  my $mypath = 'inc';

  local *DH;   # Maintain 5.005 compatibility
  opendir DH, $mypath or die "Can't open directory $mypath: $!";

  while (defined(my $e = readdir DH)) {
    next unless $e =~ /^inc_/;
    my $try = File::Spec->catfile($mypath, $e, $file);
    
    return($try, File::Spec->catdir($mypath, $e)) if -e $try;
  }
  return;
}

# Look for the given path in @INC.
sub _search_INC {
  # TODO: doesn't handle coderefs or arrayrefs or objects in @INC, but
  # it probably should
  my ($self, $file) = @_;

  foreach my $dir (@INC) {
    next if ref $dir;
    my $try = File::Spec->catfile($dir, $file);
    return $try if -e $try;
  }

  return;
}

# Translate a module name into a directory/file.pm to search for in @INC
sub _mod2path {
  my ($self, $mod) = @_;
  my @parts = split /::/, $mod;
  $parts[-1] .= '.pm';
  return $parts[0] if @parts == 1;
  return File::Spec->catfile(@parts);
}

1;

