use strict;

use Test; 
BEGIN { plan tests => 11 }
use Module::Build;
ok 1;

my $start_dir = Module::Build->cwd;

my $goto = File::Spec->catdir( $start_dir, 't', 'Sample' );
chdir $goto or die "can't chdir to $goto: $!";

# Here we make sure actions are only called once per dispatch()
$::x = 0;
my $build = Module::Build->subclass
  (
   code => "sub ACTION_loop { die 'recursed' if \$::x++; shift->depends_on('loop'); }"
  )->new( module_name => 'Sample' );
ok $build;

$build->dispatch('loop');
ok $::x, 1;

$build->dispatch('realclean');

{
  # Make sure globbing works in filenames
  $build->test_files('*t*');
  my $files = $build->test_files;
  ok  grep {$_ eq 'script'} @$files;
  ok  grep {$_ eq 'test.pl'} @$files;
  ok !grep {$_ eq 'Build.PL'} @$files;

  # Make sure order is preserved
  $build->test_files('foo', 'bar');
  $files = $build->test_files;
  ok @$files, 2;
  ok $files->[0], 'foo';
  ok $files->[1], 'bar';
}


{
  # Make sure we can add new kinds of stuff to the build sequence

  my $build = Module::Build->new( module_name => 'Sample',
				  foo_files => {'test.foo', 'lib/test.foo'} );
  ok $build;

  $build->add_build_element('foo');
  $build->dispatch('build');
  ok -e File::Spec->catfile($build->blib, 'lib', 'test.foo');

  $build->dispatch('realclean');
}
