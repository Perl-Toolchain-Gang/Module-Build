#!/usr/bin/perl

use strict;
use Test;
BEGIN { plan tests => 1 }

use Module::Build;
use File::Spec;

my $file = File::Spec->catfile('t', 'Sample', 'lib', 'Sample.pm');
ok( Module::Build->version_from_file( $file ), '0.01', 'version_from_file' );

