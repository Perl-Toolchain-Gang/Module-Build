#!/usr/bin/perl -w

use strict;
use lib $ENV{PERL_CORE} ? '../lib/Module/Build/t/lib' : 't/lib';
use MBTest tests => 5;

require_ok('Module::Build');
ensure_blib('Module::Build');

my $tmp = MBTest->tmpdir;

use DistGen;
my $dist = DistGen->new( dir => $tmp );
$dist->regen;
END{ $dist->remove }

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

