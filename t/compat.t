use Test;
use Module::Build;
use Module::Build::Compat;
use File::Spec;
use File::Path;
use Config;
require File::Spec->catfile('t', 'common.pl');

skip_test("Don't know how to invoke 'make'")
  unless $Config{make} and find_in_path($Config{make});
plan tests => 5 + 3*13;
ok(1);  # Loaded

my @make = $Config{make} eq 'nmake' ? ('nmake', '-nologo') : ($Config{make});

my $goto = File::Spec->catdir( Module::Build->cwd, 't', 'Sample' );
chdir $goto or die "can't chdir to $goto: $!";

my $build = Module::Build->new_from_context;
ok $build;

foreach my $type (qw(small passthrough traditional)) {
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
  test_makefile_creation($build, [], 'verbose', 1);
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
