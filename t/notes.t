
use strict;
use Test;
plan tests => 4;

use Module::Build;
ok(1);

###################################
my $m = Module::Build->instance;

# This was set in Build.PL
ok $m->notes('foo'), 'bar';

# Try setting & checking a new value
$m->notes(argh => 'new');
ok $m->notes('argh'), 'new';

# Change existing value
$m->notes('foo'), 'foo';
ok $m->notes('foo'), 'foo';
