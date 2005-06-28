#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use File::Spec ();
my $common_pl = File::Spec->catfile( 't', 'common.pl' );
require $common_pl;

#########################

use Test::More;

if ( $ENV{TEST_SIGNATURE} ) {
  if ( have_module( 'Module::Signature' ) ) {
    plan tests => 7;
  } else {
    plan skip_all => '$ENV{TEST_SIGNATURE} is set, but Module::Signature not found';
  }
} else {
  plan skip_all => '$ENV{TEST_SIGNATURE} is not set';
}

#########################


use Cwd ();
my $cwd = Cwd::cwd;


use Module::Build;

my $base_dir = File::Spec->catdir( $cwd, 't', 'Sample' );
chdir $base_dir or die "can't chdir to $base_dir: $!";


my $build = Module::Build->new( module_name => 'Sample',
			        requires => { 'File::Spec' => 0 },
			        license => 'perl',
			        sign => 1,
			      );

{
  eval {$build->dispatch('distdir')};
  ok ! $@;
  chdir $build->dist_dir or die "Can't chdir to ", $build->dist_dir, ": $!";
  ok -e 'SIGNATURE';
  
  # Make sure the signature actually verifies
  ok Module::Signature::verify() == Module::Signature::SIGNATURE_OK();
  chdir $base_dir or die "can't chdir back to $base_dir: $!";
}

{
  # Fake out Module::Signature and Module::Build - the first one to
  # run should be distmeta.
  my @run_order;
  {
    local $^W; # Skip 'redefined' warnings
    local *Module::Signature::sign              = sub { push @run_order, 'sign' };
    local *Module::Build::Base::ACTION_distmeta = sub { push @run_order, 'distmeta' };
    eval { $build->dispatch('distdir') };
  }
  ok ! $@;
  is $run_order[0], 'distmeta';
  is $run_order[1], 'sign';
}

eval { $build->dispatch('realclean') };
ok ! $@;
