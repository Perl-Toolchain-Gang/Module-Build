
use strict;
use Test;
plan tests => 9;

use Module::Build;
ok(1);

###################################
my $m = Module::Build->current;

# This was set in Build.PL
ok $m->notes('foo'), 'bar';

# Try setting & checking a new value
$m->notes(argh => 'new');
ok $m->notes('argh'), 'new';

# Change existing value
$m->notes(foo => 'foo');
ok $m->notes('foo'), 'foo';

# Change back so we can run this test again successfully
$m->notes(foo => 'bar');
ok $m->notes('foo'), 'bar';

###################################
# Make sure notes set before create_build_script() get preserved
my $testdir = Module::Build->localize_file_path('t/Sample');
chdir $testdir or die "Can't chdir($testdir): $!";
$m = Module::Build->new(module_name => 'Sample');
ok $m;
$m->notes(foo => 'bar');
ok $m->notes('foo'), 'bar';

$m->create_build_script;

$m = Module::Build->resume;
ok $m;
ok $m->notes('foo'), 'bar';
