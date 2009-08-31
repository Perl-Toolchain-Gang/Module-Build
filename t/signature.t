#!/usr/bin/perl -w

use strict;
use lib $ENV{PERL_CORE} ? '../lib/Module/Build/t/lib' : 't/lib';
use MBTest;

if ( $ENV{TEST_SIGNATURE} ) {
  if ( have_module( 'Module::Signature' ) ) {
    plan tests => 14;
  } else {
    plan skip_all => '$ENV{TEST_SIGNATURE} is set, but Module::Signature not found';
  }
} else {
  plan skip_all => '$ENV{TEST_SIGNATURE} is not set';
}

blib_load('Module::Build');

#########################

my $tmp = MBTest->tmpdir;

use DistGen;
my $dist = DistGen->new( dir => $tmp );
$dist->change_build_pl
({
  module_name => $dist->name,
  license     => 'perl',
  sign        => 1,
});
$dist->regen;

$dist->chdir_in;

#########################

my $mb = Module::Build->new_from_context;


{
  eval {$mb->dispatch('distdir')};
  is $@, '';
  chdir( $mb->dist_dir ) or die "Can't chdir to '@{[$mb->dist_dir]}': $!";
  ok -e 'SIGNATURE';
  
  # Make sure the signature actually verifies
  ok Module::Signature::verify() == Module::Signature::SIGNATURE_OK();
  $dist->chdir_in;
}

{
  # Fake out Module::Signature and Module::Build - the first one to
  # run should be distmeta.
  my @run_order;
  {
    local $^W; # Skip 'redefined' warnings
    local *Module::Signature::sign;
    *Module::Signature::sign = sub { push @run_order, 'sign' };
    local *Module::Build::Base::ACTION_distmeta;
    *Module::Build::Base::ACTION_distmeta = sub { push @run_order, 'distmeta' };
    eval { $mb->dispatch('distdir') };
  }
  is $@, '';
  is $run_order[0], 'distmeta';
  is $run_order[1], 'sign';
}

eval { $mb->dispatch('realclean') };
is $@, '';


{
  eval {$mb->dispatch('distdir', sign => 0 )};
  is $@, '';
  chdir( $mb->dist_dir ) or die "Can't chdir to '@{[$mb->dist_dir]}': $!";
  ok !-e 'SIGNATURE', './Build distdir --sign 0 does not sign';
}

eval { $mb->dispatch('realclean') };
is $@, '';

$dist->chdir_in;

{
    local @ARGV = '--sign=1';
    $dist->change_build_pl({
        module_name => $dist->name,
        license     => 'perl',
    });
    $dist->regen;
    
    my $mb = Module::Build->new_from_context;
    is $mb->{properties}{sign}, 1;
    
    eval {$mb->dispatch('distdir')};
    is $@, '';
    chdir( $mb->dist_dir ) or die "Can't chdir to '@{[$mb->dist_dir]}': $!";
    ok -e 'SIGNATURE', 'Build.PL --sign=1 signs';
}

# cleanup
$dist->remove;
