#!/usr/bin/perl

use strict;
use warnings;

use Cwd qw( cwd );
use File::Spec;
use File::Path qw( rmtree );

use Test;
BEGIN { plan tests => 12 }

use Module::Build;

BEGIN {
  $::cwd = cwd();
  $::install = File::Spec->catdir( $::cwd, 't', '_tmp' );
  chdir File::Spec->catdir( 't','Sample' );
  $SIG{__DIE__} = \&cleanup;
  sub cleanup {
    print "Deleting $::install\n";
    File::Path::rmtree($::install, 0, 0);
    chdir $::cwd or die "Can't cd back to $::cwd: $!";
  }
}

my $m = new Module::Build
  (
   install_base => $::install,
   module_name  => 'Sample',
   scripts      => [ 'script', File::Spec->catfile( 'bin', 'sample.pl' ) ],
  );

ok( ref $m->{properties}->{bindoc_dirs}, 'ARRAY', 'bindoc_dirs' );
ok( ref $m->{properties}->{libdoc_dirs}, 'ARRAY', 'libdoc_dirs' );

my %man = (
	   sep  => $m->manpage_separator,
	   dir1 => 'man1',
	   dir3 => 'man3',
	   ext1 => $m->{config}{man1ext},
	   ext3 => $m->{config}{man3ext},
	  );

my @expected_bindocs = ( "sample.pl.$man{ext1}" );
my @expected_libdocs = ( "Sample.$man{ext3}", "Sample$man{sep}Docs.$man{ext3}" );
my @unexpected_bindocs = ( "script.$man{ext1}" );
my @unexpected_libdocs = ( "Sample$man{sep}NoPod.$man{ext3}" );


$m->dispatch('build');

ok( $m->dispatch('builddocs') );
ok( -e $_, 1, "$_ manpage was *not* created" ) for
  map { File::Spec->catfile( 'blib', 'bindoc', $_ ) } @expected_bindocs;
ok( -e $_, 1, "$_ manpage was *not* created" ) for
  map { File::Spec->catfile( 'blib', 'libdoc', $_ ) } @expected_libdocs;
ok(! -e $_, 1, "$_ manpage *was* created" ) for
  map { File::Spec->catfile( 'blib', 'bindoc', $_ ) } @unexpected_bindocs;
ok(! -e $_, 1, "$_ manpage *was* created" ) for
  map { File::Spec->catfile( 'blib', 'libdoc', $_ ) } @unexpected_libdocs;


$m->dispatch('install');

ok( -e $_, 1, "$_ manpage was *not* installed" ) for
  map { File::Spec->catfile( $::install, 'man', $man{dir1}, $_ ) } @expected_bindocs;
ok( -e $_, 1, "$_ manpage was *not* installed" ) for
  map { File::Spec->catfile( $::install, 'man', $man{dir3}, $_ ) } @expected_libdocs;


$m->dispatch('realclean');


my $m2 = new Module::Build
  (
   module_name     => 'Sample',
   libdoc_dirs => [qw( foo bar baz )],
  );

ok( $m2->{properties}->{libdoc_dirs}->[0], 'foo', 'override libdoc_dirs' );


cleanup();

