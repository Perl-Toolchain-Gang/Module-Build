######################### We start with some black magic to print on failure.

use strict;
use Test;

BEGIN { plan tests => 6 }

use Module::Build;
use File::Spec;
ok(1);

######################### End of black magic.

# Pretend we're in the t/XSTest/ subdirectory
my $build_dir = File::Spec->catdir('t','XSTest');
chdir $build_dir or die "Can't change to $build_dir : $!";

my $m = new Module::Build
  (
   module_name => 'XSTest',
  );
ok(1);

$m->dispatch('clean');
ok(1);
$m->dispatch('build');
ok(1);

# We can't be verbose in the sub-test, because Test::Harness will think that the output is for the top-level test.
$m->dispatch('test');
ok(1);
$m->dispatch('realclean');
ok(1);

