use strict;

# Tests various ways to extend Module::Build, e.g. by subclassing.
use File::Spec;
BEGIN {
  my $common_pl = File::Spec->catfile('t', 'common.pl');
  require $common_pl;
}

use Test::More tests => 52;
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
is $::x, 1;

$build->dispatch('realclean');

# Make sure the subclass can be subclassed
my $build2class = ref($build)->subclass
  (
   code => "sub ACTION_loop2 {}",
   class => 'MBB',
  );
can_ok( $build2class, 'ACTION_loop' );
can_ok( $build2class, 'ACTION_loop2' );


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
  is @$files, 2;
  is $files->[0], 'foo';
  is $files->[1], 'bar';
}


{
  # Make sure we can add new kinds of stuff to the build sequence

  my $build = Module::Build->new( module_name => 'Sample',
				  foo_files => {'test.foo', 'lib/test.foo'} );
  ok $build;

  $build->add_build_element('foo');
  $build->dispatch('build');
  is -e File::Spec->catfile($build->blib, 'lib', 'test.foo'), 1;

  $build->dispatch('realclean');
}


{
  package MBSub;
  use Test::More;
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
  like "$@", qr/already exists/;
}

{
  package MBSub2;
  use Test::More;
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
  isa_ok $build, 'Module::Build';
  isa_ok $build, 'MBSub';
  ok $build->valid_property('foo');
  can_ok $build, 'module_name';
  
  # Check foo property.
  can_ok $build, 'foo';
  ok ! $build->foo;
  ok $build->foo(1);
  ok $build->foo;
  
  # Check bar property.
  can_ok $build, 'bar';
  is $build->bar, 'hey';
  ok $build->bar('you');
  is $build->bar, 'you';
  
  # Check hash property.
  ok $build = MBSub->new(
			 module_name => 'ModuleBuildOne',
			 hash        => { foo => 'bar', bin => 'foo'}
			);
  
  can_ok $build, 'hash';
  isa_ok $build->hash, 'HASH';
  is $build->hash->{foo}, 'bar';
  is $build->hash->{bin}, 'foo';
  
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

  can_ok $build, 'hash';
  isa_ok $build->hash, 'HASH';
  is $build->hash->{foo}, 'bar';
  is $build->hash->{bin}, 'foo';
  
  # Make sure that a different subclass with the same named property has a
  # different default.
  ok $build = MBSub2->new( module_name => 'ModuleBuildOne' );
  isa_ok $build, 'Module::Build';
  isa_ok $build, 'MBSub2';
  ok $build->valid_property('bar');
  can_ok $build, 'bar';
  is $build->bar, 'yow';
}

{
  # Test the meta_add and meta_merge stuff
  chdir $goto;
  ok my $build = Module::Build->new(
				    module_name => 'Sample',
				    meta_add => {foo => 'bar'},
				    conflicts => {'Foo::Barxx' => 0},
				   );
  my %data;
  $build->prepare_metadata( \%data );
  is $data{foo}, 'bar';

  $build->meta_merge(foo => 'baz');
  $build->prepare_metadata( \%data );
  is $data{foo}, 'baz';

  $build->meta_merge(conflicts => {'Foo::Fooxx' => 0});
  $build->prepare_metadata( \%data );
  is_deeply $data{conflicts}, {'Foo::Barxx' => 0, 'Foo::Fooxx' => 0};

  $build->meta_add(conflicts => {'Foo::Bazxx' => 0});
  $build->prepare_metadata( \%data );
  is_deeply $data{conflicts}, {'Foo::Bazxx' => 0, 'Foo::Fooxx' => 0};
}
