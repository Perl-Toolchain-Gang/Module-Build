use strict;
use Test;
use Module::Build;
use Module::Build::Compat;
use File::Spec;
use File::Path;
use Config;
require File::Spec->catfile('t', 'common.pl');

# Don't let our own verbosity/test_file get mixed up with our subprocess's
my @makefile_keys = qw(TEST_VERBOSE HARNESS_VERBOSE TEST_FILES MAKEFLAGS);
local  @ENV{@makefile_keys};
delete @ENV{@makefile_keys};

skip_test("Don't know how to invoke 'make'")
  unless $Config{make} and find_in_path($Config{make});

my @makefile_types = qw(small passthrough traditional);
my $tests_per_type = 10;
plan tests => 27 + @makefile_types*$tests_per_type;
ok(1);  # Loaded

my @make = $Config{make} eq 'nmake' ? ('nmake', '-nologo') : ($Config{make});

my $goto = File::Spec->catdir( Module::Build->cwd, 't', 'Sample' );
chdir $goto or die "can't chdir to $goto: $!";

my $build = Module::Build->new_from_context;
ok $build;

foreach my $type (@makefile_types) {
  Module::Build::Compat->create_makefile_pl($type, $build);
  test_makefile_creation($build);
  
  ok $build->do_system(@make);
  
  # Can't let 'test' STDOUT go to our STDOUT, or it'll confuse Test::Harness.
  my $success;
  my $output = stdout_of( sub {
			    $success = $build->do_system(@make, 'test');
			  } );
  ok $success;
  ok uc $output, qr{DONE\.|SUCCESS};
  
  ok $build->do_system(@make, 'realclean');
  
  # Try again with some Makefile.PL arguments
  test_makefile_creation($build, [], 'INSTALLDIRS=vendor', 1);
  
  1 while unlink 'Makefile.PL';
  ok -e 'Makefile.PL', undef;
}

{
  # Make sure fake_makefile() can run without 'build_class', as it may be
  # in older-generated Makefile.PLs
  my $warning = '';
  local $SIG{__WARN__} = sub { $warning = shift; };
  my $maketext = eval { Module::Build::Compat->fake_makefile(makefile => 'Makefile') };
  ok $@, '';
  ok $maketext, qr/^realclean/m;
  ok $warning, qr/build_class/;
}

{
  # Make sure custom builder subclass is used in the created
  # Makefile.PL - make sure it fails in the right way here.
  local @Foo::Builder::ISA = qw(Module::Build);
  my $foo_builder = Foo::Builder->new_from_context();
  foreach my $style ('passthrough', 'small') {
    Module::Build::Compat->create_makefile_pl($style, $foo_builder);
    ok -e 'Makefile.PL';
    
    # Should fail with "can't find Foo/Builder.pm"
    my $warning = stderr_of
      (sub {
	 my $result = $build->run_perl_script('Makefile.PL');
	 ok !$result;
       });
    ok $warning, qr{Foo/Builder.pm};
  }
  
  # Now make sure it can actually work.
  my $bar_builder = Module::Build->subclass( class => 'Bar::Builder' )->new_from_context;
  foreach my $style ('passthrough', 'small') {
    Module::Build::Compat->create_makefile_pl($style, $bar_builder);
    ok -e 'Makefile.PL';
    ok $build->run_perl_script('Makefile.PL');
  }
}

{
  # Make sure various Makefile.PL arguments are supported
  Module::Build::Compat->create_makefile_pl('passthrough', $build);

  my $libdir = File::Spec->catdir( Module::Build->cwd, 't', 'libdir' );
  my $result = $build->run_perl_script('Makefile.PL', [], 
				       [
					"LIB=$libdir",
					'TEST_VERBOSE=1',
					'INSTALLDIRS=perl',
					'POLLUTE=1',
				       ]
				      );
  ok $result;
  ok -e 'Build.PL', 1;

  my $new_build = Module::Build->resume();
  ok $new_build->installdirs, 'core';
  ok $new_build->verbose, 1;
  ok $new_build->install_destination('lib'), $libdir;
  ok $new_build->extra_compiler_flags->[0], '-DPERL_POLLUTE';

  # Make sure those switches actually had an effect
  my ($ran_ok, $output);
  $output = stdout_of( sub { $ran_ok = $new_build->do_system(@make, 'test') } );
  ok $ran_ok;
  $output =~ s/^/# /gm;  # Don't confuse our own test output
  ok $output, qr/# ok 1\s+# ok 2\s+/, 'Should be verbose';

  # Make sure various Makefile arguments are supported
  $output = stdout_of( sub { $ran_ok = $build->do_system(@make, 'test', 'TEST_VERBOSE=0') } );
  ok $ran_ok;
  $output =~ s/^/# /gm;  # Don't confuse our own test output
  ok $output, qr/# test\.+ok\s+# All/, 'Should be non-verbose';
  
  $build->do_system(@make, 'realclean');
  ok -e 'Makefile', undef, "Makefile shouldn't exist";

  1 while unlink 'Makefile.PL';
  ok -e 'Makefile.PL', undef;
}

#########################################################

sub test_makefile_creation {
  my ($build, $preargs, $postargs, $cleanup) = @_;
  
  my $result = $build->run_perl_script('Makefile.PL', $preargs, $postargs);
  ok $result;
  ok -e 'Makefile', 1, "Makefile should exist";
  
  if ($cleanup) {
    $build->do_system(@make, 'realclean');
    ok -e 'Makefile', undef, "Makefile shouldn't exist";
  }
}
