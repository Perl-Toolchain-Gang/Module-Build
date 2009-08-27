# sample.t -- a sample test file for Module::Build

use strict;
use lib $ENV{PERL_CORE} ? '../lib/Module/Build/t/lib' : 't/lib';
use MBTest tests => 4; # or 'no_plan'
use DistGen;

# TESTS BEGIN HERE

require_ok('Module::Build');
ensure_blib('Module::Build');

# create dist object in a temp directory
# MBTest uses different dirs for Perl core vs CPAN testing 
my $dist = DistGen->new( dir => MBTest->tmpdir );

# generate the skeleton files and also schedule cleanup
$dist->regen;
END{ $dist->remove }

# enter the test distribution directory before further testing
$dist->chdir_in;

# get a Module::Build object and test with it
my $mb = $dist->new_from_context( quiet => 1 );
isa_ok( $mb, "Module::Build" );
is( $mb->dist_name, "Simple", "dist_name is 'Simple'" );

