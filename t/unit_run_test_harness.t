#!/usr/bin/perl -w

use strict;
use lib 't/lib';
use MBTest tests => 5;

blib_load('Module::Build');

my $tmp = MBTest->tmpdir;

use DistGen;
my $dist = DistGen->new( dir => $tmp );
$dist->regen;

$dist->chdir_in;

#########################


# Test object creation
{
  # make sure Test::Harness loaded before we define Test::Harness::runtests otherwise we'll
  # get another redefined warning inside Test::Harness::runtests
  use Test::Harness;

  local $SIG{__WARN__} = sub { die "Termination after a warning: $_[0]"};

  my $mock1 = { A => 1 };
  my $mock2 = { B => 2 };
  
  my $mb = Module::Build->new( module_name => $dist->name );
  no warnings qw[redefine once];
  local *Module::Build::harness_switches = sub { return };
  local *Test::Harness::runtests = sub {
	ok shift == $mock1, "runtests ran with expected parameters";
	ok shift == $mock2, "runtests ran with expected parameters";
  };

  # $Test::Harness::switches and $Test::Harness::switches are aliases, but we pretend we don't know this
  $Test::Harness::switches = undef;
  $Test::Harness::switches = undef;
  $mb->run_test_harness([$mock1, $mock2]);

  ok 1, "run_test_harness should not produce warning if Test::Harness::[Ss]witches are undef and harness_switches() return empty list";

  ok ! defined $Test::Harness::switches, "switches are undef";
  ok ! defined $Test::Harness::Switches, "switches are undef";
}


