#!perl -w
use strict;
use Test;
use File::Spec;

my $common_pl = File::Spec->catfile('t', 'common.pl');
require $common_pl;

use Module::Build;
skip_test("Skipping unless \$ENV{TEST_SIGNATURE} is true") unless $ENV{TEST_SIGNATURE};
need_module('Module::Signature');
plan tests => 7;


my $base_dir = File::Spec->catdir( Module::Build->cwd, 't', 'Sample' );
chdir $base_dir or die "can't chdir to $base_dir: $!";


my $build = new Module::Build( module_name => 'Sample',
			       requires => { 'File::Spec' => 0 },
			       license => 'perl',
			       sign => 1,
			     );

{
  eval {$build->dispatch('distdir')};
  ok $@, '';
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
  ok $@, '';
  ok $run_order[0], 'distmeta';
  ok $run_order[1], 'sign';
}

eval { $build->dispatch('realclean') };
ok $@, '';
