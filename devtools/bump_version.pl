#!/usr/bin/env perl
use strict;
use warnings;

use Tie::File;

eval { require File::Find::Rule }
  or die "$0 requires File::Find::Rule. Please install it and try again.\n";

# Get version from command line
my $version = shift
  or die "Usage: $0 <version>\n";

# XXX check if $version is greater than existing?

# NEVER BUMP THESE $VERSION numbers
my @excluded = qw(
  lib/Module/Build/Version.pm
  lib/Module/Build/YAML.pm
);

# Get list of .pm files
my @pmfiles = File::Find::Rule->new->or(
  File::Find::Rule->name('*.pm'),
  File::Find::Rule->directory->name( qr/\.svn/ )->prune->discard
)->in( 'lib' );
my @scripts = File::Find::Rule->new()->name('*')->in( './scripts' );

for my $file ( @pmfiles, @scripts ) {
  next if grep { $file eq $_ } @excluded;
  bump_version( $file, $version );
}

exit;

sub bump_version {
  my ( $file, $version ) = @_;
  my $o = tie my @lines, 'Tie::File', $file 
    or die "Couldn't tie '$file' for editing\n";
  $o->flock;

  # find line to change just like EU::MM::parse_version
  my $inpod = 0;
  for ( @lines ) {
      $inpod = /^=(?!cut)/ ? 1 : /^=cut/ ? 0 : $inpod;
      next if $inpod || /^\s*#/;
      next unless /(?<!\\)([\$*])(([\w\:\']*)\bVERSION)\b.*\=/;
      $_ = "\$VERSION = '$version';"; 
      print "Updated $file\n";
      last;
  }

  undef $o; untie @lines;
  return;
}

