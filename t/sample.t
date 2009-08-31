# sample.t -- a sample test file for Module::Build

use strict;
use lib $ENV{PERL_CORE} ? '../lib/Module/Build/t/lib' : 't/lib';
use MBTest tests => 2; # or 'no_plan'
use DistGen;

# Ensure any Module::Build modules are loaded from correct directory
blib_load('Module::Build');

# create dist object in a temp directory
# MBTest uses different dirs for Perl core vs CPAN testing 
my $dist = DistGen->new;

# generate the skeleton files and also schedule cleanup
$dist->regen;
END{ $dist->remove }

# enter the test distribution directory before further testing
$dist->chdir_in;

# get a Module::Build object and test with it
my $mb = $dist->new_from_context( quiet => 1 );
isa_ok( $mb, "Module::Build" );
is( $mb->dist_name, "Simple", "dist_name is 'Simple'" );

# vim:ts=2:sw=2:et:sta:sts=2
