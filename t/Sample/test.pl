#!/usr/bin/perl

use Test;
plan tests => 2;

ok 1;

require Module::Build;
ok $INC{'Module/Build.pm'}, qr/blib/, 'Module::Build should be loaded from blib';
