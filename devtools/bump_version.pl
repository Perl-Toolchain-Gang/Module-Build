#!/usr/bin/env perl

# NOTE: we run this immediately *after* a release so that any reports
# against the repo are obvious

use strict;
use warnings;

use lib 'lib';
use lib 'inc';
use ModuleBuildBuilder;

use Tie::File;

eval { require File::Find::Rule } or
  die "$0 requires File::Find::Rule. Please install and try again.\n";

my $current = ModuleBuildBuilder->new_from_context(quiet => 1)->dist_version;

# Get version from command line or prompt
my $version = shift;
unless($version) {
  my $default = $current;

  # try to construct a reasonable default automatically
  $default =~ s/(\d+)$// or
    die "Usage: $0 VERSION\ncurrently: $current\n";
  my $end = $1;
  $default .= sprintf('%0'.length($end).'d', $end+1);

  local $| = 1;
  print "enter new version [$default]: ";
  chomp(my $ans = <STDIN>);
  $version = $ans ? $ans : $default;
  # TODO check for garbage in?
}

die "must bump forward! ($version < $current)\n"
  unless(eval $version >= eval $current);

# NEVER BUMP THESE $VERSION numbers
my @excluded = qw(
  lib/Module/Build/Version.pm
  lib/Module/Build/YAML.pm
);

# Get list of .pm files
my @pmfiles = File::Find::Rule->new->or(
  File::Find::Rule->name('*.pm'),
)->in( 'lib' );
my @scripts = File::Find::Rule->new()->or(
  File::Find::Rule->name('*'),
)->in( './scripts' );

# first start the new Changes entry
sub {
  my $file = 'Changes';
  open(my $fh, '<', $file) or die "cannot read '$file' $!";
  my @lines = <$fh>;
  my @head;
  while(@lines) {
    my $line = shift(@lines);
    if($line =~ m/^$current/ ) {
      # unreleased case -- re-bumping
      if($line =~ m/^$current(?: *- *)?$/) {
        print "Error parsing $file - found unreleased '$current'\n"; 
        local $| = 1;
        print "Are you sure you want to change the version number (y/n)? [n]:";
        chomp(my $ans = <STDIN>);
        if ( $ans !~ /^y/i ) {
          print "Aborting!\n";
          exit 1;
        }
        warn "Updating '$file'\n";
        open(my $ofh, '>', $file) or die "cannot write '$file' $!";
        print $ofh @head, "$version - \n", @lines;
        close($ofh) or die "cannot write '$file' $!";
        return;
      }
      if($line =~ m/^$current - \w/) {
        warn "Updating '$file'\n";
        open(my $ofh, '>', $file) or die "cannot write '$file' $!";
        print $ofh @head, "$version - \n", "\n", $line, @lines;
        close($ofh) or die "cannot write '$file' $!";
        return;
      }
      elsif($line =~ m/^$version(?: *- *)?$/) {
        # TODO should just be checking for a general number+eol case?
        die "$file probably needs to be reverted!";
      }
    }
    else {
      push(@head, $line);
    }
  }
  die "cannot find changes entry for current version ($current)!";
}->();

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
      # TODO check that what we found matches $current?
      $_ = "\$VERSION = '$version';"; 
      warn "Updated $file\n";
      last;
  }

  undef $o; untie @lines;
  return;
}

# vi:ts=2:sw=2:et:sta
