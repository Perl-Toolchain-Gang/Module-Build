#!/usr/bin/perl

use Test;
plan tests => 2;

ok 1;

# Make sure Module::Build was loaded from blib/
require Module::Build;
print "\$INC{'Module/Build.pm'}: $INC{'Module/Build.pm'}\n";
ok $INC{'Module/Build.pm'}, qr/blib/;
print "Done.\n";
