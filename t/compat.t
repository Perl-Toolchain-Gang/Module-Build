use Test;
BEGIN { plan tests => 11 }

use Module::Build;
use Module::Build::Compat;
use File::Spec;
use File::Path;
ok(1);  # Loaded


my $goto = File::Spec->catdir( Module::Build->cwd, 't', 'Sample' );
chdir $goto or die "can't chdir to $goto: $!";

my $build = Module::Build->new
  ( module_name => 'Sample',
    requires => { File::Spec => 0, File::Path => $File::Path::VERSION },
    build_requires => { Module::Build => 0 },
  );
ok $build;

$build->add_to_cleanup('Makefile.PL');

foreach my $type (qw(small passthrough traditional)) {
  Module::Build::Compat->create_makefile_pl($type, $build);
  my $result = $build->run_perl_script('Makefile.PL');
  ok $result;

  ok $build->do_system('make', 'realclean');
  $build->dispatch('realclean');
  ok not -e 'Makefile.PL';
}
