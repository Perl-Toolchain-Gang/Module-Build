#!perl -w
use strict;
use Test;
use File::Spec;
require File::Spec->catfile('t', 'common.pl');

use Module::Build;
need_module('Module::Signature');
plan tests => 6;

{
  my $base_dir = File::Spec->catdir( Module::Build->cwd, 't', 'Sample' );
  chdir $base_dir or die "can't chdir to $base_dir: $!";
}

my $build = new Module::Build( module_name => 'Sample',
			       license => 'perl',
			       sign => 1,
			     );

{
  eval {$build->dispatch('distdir')};
  ok $@, '';
  ok -e File::Spec->catfile($build->dist_dir, 'SIGNATURE');
}

{
  # Fake out Module::Signature and Module::Build - the first one to
  # run should be distmeta.
  my @run_order;
  local *Module::Signature::sign              = sub { push @run_order, 'sign' };
  local *Module::Build::Base::ACTION_distmeta = sub { push @run_order, 'distmeta' };
  eval { $build->dispatch('distdir') };
  ok $@, '';
  ok $run_order[0], 'distmeta';
  ok $run_order[1], 'sign';
}

eval { $build->dispatch('realclean') };
ok $@, '';
