
use strict;
use Test;
plan tests => 4;

use Module::Build;
ok(1);

###################################
my $m = Module::Build->instance;

ok $m->notes('foo'), 'bar';

$m->notes(argh => 'new');
ok $m->notes('argh'), 'new';

$m->notes('foo'), 'foo';
ok $m->notes('foo'), 'foo';
