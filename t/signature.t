#!perl -w
use strict;
use Test;
use File::Spec;
require File::Spec->catfile('t', 'common.pl');

use Module::Build;
need_module('Module::Signature');
plan tests => 5;

my $start_dir = Module::Build->cwd;
my $goto = File::Spec->catdir( $start_dir, 't', 'Sample' );
chdir $goto or die "can't chdir to $goto: $!";

my $build = new Module::Build( module_name => 'Sample',
			       license => 'perl',
			       sign => 1,
			     );

{
  # The following doesn't actually seem to work, it has some problem
  # with the Sample-0.01/ directory.
  eval {$build->dispatch('dist')};
  ok $@, '';
  ok -e File::Spec->catdir('Sample-0.01', 'SIGNATURE');
}

{
  # Fake out Module::Signature; subclass and override distmeta;
  # the first one to run should be distmeta.
  local *Module::Signature::sign              = sub { $::ranfirst ||= 'sign' };
  local *Module::Build::Base::ACTION_distmeta = sub { $::ranfirst ||= 'distmeta' };
  eval { $build->dispatch('distsign') };
  ok $@, '';
  ok $::ranfirst eq 'distmeta';
}

eval { $build->dispatch('realclean') };
ok $@, '';
