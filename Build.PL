# We use Module::Build to test & install itself.  On some platforms
# (*ahem*, MacOS 5.6.1) "use lib qw(lib);" doesn't find the local
# "lib" directory, so we use File::Spec to do it properly.

use File::Spec;
use lib File::Spec->catdir('lib');
use Module::Build;

my $build = new Module::Build
  (
   module_name => 'Module::Build',   
   license => 'perl',
   requires => {
		perl           => '5.6.0',
		Config         => 0,
		File::Copy     => 0,
		File::Find     => 0,
		File::Path     => 0,
		File::Basename => 0,
		File::Spec     => 0,
		Data::Dumper   => 0,
		ExtUtils::Install => 0,
		Cwd            => 0,
	       },
   recommends => {
		  YAML => 0.35,
		  Archive::Tar => 0.22,
		  ExtUtils::Install => 0.30,
		 },
   build_requires => {
		      Test => 0,
		     },
  );

$build->create_build_script;
