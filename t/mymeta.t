#!/usr/bin/perl -w

use strict;
use lib 't/lib';
use MBTest;
plan tests => 7;

blib_load('Module::Build');

my $tmp = MBTest->tmpdir;

use DistGen;
my $dist = DistGen->new( dir => $tmp );
$dist->regen;
$dist->chdir_in;

#########################

# Test MYMETA generation
{
  ok( ! -e "MYMETA.yml", "MYMETA.yml doesn't exist before Build.PL runs" );
  my $output;
  $output = stdout_of sub { $dist->run_build_pl };
  like($output, qr/Creating new 'MYMETA.yml' with configuration results/,
    "Saw MYMETA.yml creation message"
  );
  ok( -e "MYMETA.yml", "MYMETA.yml exists" );
}

#########################

{
  my $output = stdout_stderr_of sub { $dist->run_build('distcheck') };
  like($output, qr/Creating a temporary 'MANIFEST.SKIP'/,
    "MANIFEST.SKIP created for distcheck"
  );
  unlike($output, qr/MYMETA/,
    "MYMETA not flagged by distcheck"
  );
}


{
  my $output = stdout_stderr_of sub { $dist->run_build('distclean') };
  ok( ! -f 'MYMETA.yml', "No MYMETA.yml after distclean" );
  ok( ! -f 'MANIFEST.SKIP', "No MANIFEST.SKIP after distclean" );
}


