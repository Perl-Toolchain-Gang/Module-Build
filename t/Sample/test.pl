#!/usr/bin/perl

use Test;
plan tests => 2;

ok 1;

# Make sure Module::Build was loaded from blib/
require Module::Build;
ok $INC{'Module/Build.pm'}, qr/blib/;
