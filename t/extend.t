use strict;

use Test; 
BEGIN { plan tests => 3 }
use Module::Build;
ok 1;

my $start_dir = Module::Build->cwd;

my $goto = File::Spec->catdir( $start_dir, 't', 'Sample' );
chdir $goto or die "can't chdir to $goto: $!";

# Here we make sure actions are only called once per dispatch()
my $build = Module::Build->subclass
  (
   code => "sub ACTION_loop { die 'recursed' if \$::x++; shift->depends_on('loop'); }"
  )->new( module_name => 'Sample' );
ok $build;

$build->dispatch('loop');
ok $::x, 1;

$build->dispatch('realclean');
