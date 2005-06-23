use lib 't/lib';
use strict;

use Test::More tests => 9;

use Module::Build;
ok(1);

###################################
my $m = Module::Build->current;

# This was set in Build.PL
is $m->notes('foo'), 'bar';

# Try setting & checking a new value
$m->notes(argh => 'new');
is $m->notes('argh'), 'new';

# Change existing value
$m->notes(foo => 'foo');
is $m->notes('foo'), 'foo';

# Change back so we can run this test again successfully
$m->notes(foo => 'bar');
is $m->notes('foo'), 'bar';

###################################
# Make sure notes set before create_build_script() get preserved
my $testdir = Module::Build->localize_file_path('t/Sample');
chdir $testdir or die "Can't chdir($testdir): $!";
$m = Module::Build->new(module_name => 'Sample');
ok $m;
$m->notes(foo => 'bar');
is $m->notes('foo'), 'bar';

$m->create_build_script;

$m = Module::Build->resume;
ok $m;
is $m->notes('foo'), 'bar';
