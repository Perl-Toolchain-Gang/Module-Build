#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use Test::More tests => 2;

use Cwd ();
my $cwd = Cwd::cwd;

#########################

use Module::Build;
use File::Spec;

my $file = File::Spec->catfile('t', 'Sample', 'lib', 'Sample.pm');
is( Module::Build->version_from_file( $file ), '0.01', 'version_from_file' );

ok( Module::Build->compare_versions( '1.01_01', '>', '1.01' ), 'compare: 1.0_01 > 1.0' );
