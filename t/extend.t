#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use Test::More tests => 52;


use File::Spec ();
my $common_pl = File::Spec->catfile( 't', 'common.pl' );
require $common_pl;


use Cwd ();
my $cwd = Cwd::cwd;
my $tmp = File::Spec->catdir( $cwd, 't', '_tmp' );

use DistGen;
my $dist = DistGen->new( dir => $tmp );
$dist->regen;

chdir( $dist->dirname ) or die "Can't chdir to '@{[$dist->dirname]}': $!";

#########################

use Module::Build;
ok 1;

# Here we make sure actions are only called once per dispatch()
$::x = 0;
my $m = Module::Build->subclass
  (
   code => "sub ACTION_loop { die 'recursed' if \$::x++; shift->depends_on('loop'); }"
  )->new( module_name => $dist->name );
ok $m;

$m->dispatch('loop');
ok $::x;

$m->dispatch('realclean');

# Make sure the subclass can be subclassed
my $build2class = ref($m)->subclass
  (
   code => "sub ACTION_loop2 {}",
   class => 'MBB',
  );
can_ok( $build2class, 'ACTION_loop' );
can_ok( $build2class, 'ACTION_loop2' );


{ # Make sure globbing works in filenames
  $dist->add_file( 'script', <<'---' );
#!perl -w
print "Hello, World!\n";
---
  $dist->regen;

  $m->test_files('*t*');
  my $files = $m->test_files;
  ok  grep {$_ eq 'script'}    @$files;
  ok  grep {$_ eq File::Spec->catfile('t', 'basic.t')} @$files;
  ok !grep {$_ eq 'Build.PL' } @$files;

  # Make sure order is preserved
  $m->test_files('foo', 'bar');
  $files = $m->test_files;
  is @$files, 2;
  is $files->[0], 'foo';
  is $files->[1], 'bar';

  $dist->remove_file( 'script' );
  $dist->regen( clean => 1 );
}


{
  # Make sure we can add new kinds of stuff to the build sequence

  $dist->add_file( 'test.foo', "content\n" );
  $dist->regen;

  my $m = Module::Build->new( module_name => $dist->name,
			      foo_files => {'test.foo', 'lib/test.foo'} );
  ok $m;

  $m->add_build_element('foo');
  $m->dispatch('build');
  ok -e File::Spec->catfile($m->blib, 'lib', 'test.foo');

  $m->dispatch('realclean');

  # revert distribution to a pristine state
  $dist->remove_file( 'test.foo' );
  $dist->regen( clean => 1 );
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


{
  ok my $m = MBSub->new( module_name => $dist->name );
  isa_ok $m, 'Module::Build';
  isa_ok $m, 'MBSub';
  ok $m->valid_property('foo');
  can_ok $m, 'module_name';
  
  # Check foo property.
  can_ok $m, 'foo';
  ok ! $m->foo;
  ok $m->foo(1);
  ok $m->foo;
  
  # Check bar property.
  can_ok $m, 'bar';
  is $m->bar, 'hey';
  ok $m->bar('you');
  is $m->bar, 'you';
  
  # Check hash property.
  ok $m = MBSub->new(
		      module_name => $dist->name,
		      hash        => { foo => 'bar', bin => 'foo'}
		    );
  
  can_ok $m, 'hash';
  isa_ok $m->hash, 'HASH';
  is $m->hash->{foo}, 'bar';
  is $m->hash->{bin}, 'foo';
  
  # Check hash property passed via the command-line.
  {
    local @ARGV = (
		   '--hash', 'foo=bar',
		   '--hash', 'bin=foo',
		  );
    ok $m = MBSub->new(
		        module_name => $dist->name,
		      );
  }

  can_ok $m, 'hash';
  isa_ok $m->hash, 'HASH';
  is $m->hash->{foo}, 'bar';
  is $m->hash->{bin}, 'foo';
  
  # Make sure that a different subclass with the same named property has a
  # different default.
  ok $m = MBSub2->new( module_name => $dist->name );
  isa_ok $m, 'Module::Build';
  isa_ok $m, 'MBSub2';
  ok $m->valid_property('bar');
  can_ok $m, 'bar';
  is $m->bar, 'yow';
}

{
  # Test the meta_add and meta_merge stuff
  ok my $m = Module::Build->new(
				 module_name => $dist->name,
				 meta_add => {foo => 'bar'},
				 conflicts => {'Foo::Barxx' => 0},
			       );
  my %data;
  $m->prepare_metadata( \%data );
  is $data{foo}, 'bar';

  $m->meta_merge(foo => 'baz');
  $m->prepare_metadata( \%data );
  is $data{foo}, 'baz';

  $m->meta_merge(conflicts => {'Foo::Fooxx' => 0});
  $m->prepare_metadata( \%data );
  is_deeply $data{conflicts}, {'Foo::Barxx' => 0, 'Foo::Fooxx' => 0};

  $m->meta_add(conflicts => {'Foo::Bazxx' => 0});
  $m->prepare_metadata( \%data );
  is_deeply $data{conflicts}, {'Foo::Bazxx' => 0, 'Foo::Fooxx' => 0};
}


# cleanup
chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
$dist->remove;

use File::Path;
rmtree( $tmp );
