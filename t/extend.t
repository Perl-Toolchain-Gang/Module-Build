use strict;

# Tests various ways to extend Module::Build, e.g. by subclassing.

use Test; 
BEGIN { plan tests => 45 }
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


{
  package MBSub;
  use Test;
  use vars qw($VERSION @ISA);
  @ISA = qw(Module::Build);
  $VERSION = 0.01;
  
  # Add a new property.
  ok(__PACKAGE__->add_property('foo'));
  # Add a new property with a default value.
  ok(__PACKAGE__->add_property('bar', 'hey'));
  # Add a hash property.
  ok(__PACKAGE__->add_property('hash', {}));
  
  
  # Catch an exception adding an existing property.
  eval { __PACKAGE__->add_property('module_name')};
  ok "$@", qr/Property "module_name" already exists/;
}

{
  package MBSub2;
  use Test;
  use vars qw($VERSION @ISA);
  @ISA = qw(Module::Build);
  $VERSION = 0.01;
  
  # Add a new property with a different default value than MBSub has.
  ok(__PACKAGE__->add_property('bar', 'yow'));
}


chdir($start_dir) or die "Can't chdir back to $start_dir: $!";
chdir('t') or die "Can't chdir to t/: $!";
{
  ok my $build = MBSub->new( module_name => 'ModuleBuildOne' );
  ok $build->isa('Module::Build');
  ok $build->isa('MBSub');
  ok $build->valid_property('foo');
  # Ppbbbblllltttt! Stupid Test::ok doesn't know that a code reference
  # is a true value. Duh! Turns out it executes it and checks its return
  # value, instead. D'oh!  -David Wheeler
  ok !!$build->can('module_name');
  
  # Check foo property.
  ok !!$build->can('foo');
  ok ! $build->foo;
  ok $build->foo(1);
  ok $build->foo;
  
  # Check bar property.
  ok !!$build->can('bar');
  ok $build->bar, 'hey';
  ok $build->bar('you');
  ok $build->bar, 'you';
  
  # Check hash property.
  ok $build = MBSub->new(
			 module_name => 'ModuleBuildOne',
			 hash        => { foo => 'bar', bin => 'foo'}
			);
  
  ok !!$build->can('hash');
  ok ref $build->hash, 'HASH';
  ok $build->hash->{foo}, 'bar';
  ok $build->hash->{bin}, 'foo';
  
  # Check hash property passed via the command-line.
  {
    local @ARGV = (
		   '--hash', 'foo=bar',
		   '--hash', 'bin=foo',
		  );
    ok $build = MBSub->new(
			   module_name => 'ModuleBuildOne',
			  );
  }

  ok !!$build->can('hash');
  ok ref $build->hash, 'HASH';
  ok $build->hash->{foo}, 'bar';
  ok $build->hash->{bin}, 'foo';
  
  # Make sure that a different subclass with the same named property has a
  # different default.
  ok $build = MBSub2->new( module_name => 'ModuleBuildOne' );
  ok $build->isa('Module::Build');
  ok $build->isa('MBSub2');
  ok $build->valid_property('bar');
  ok !!$build->can('bar');
  ok $build->bar, 'yow';
}
