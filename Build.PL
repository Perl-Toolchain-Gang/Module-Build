use lib qw(lib);  # Use Module::Build to test & install itself
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
		Cwd            => 0,
	       },
   recommends => {
		  YAML => 0.35,
		  Archive::Tar => 0.22,
		 },
   build_requires => {
		      Test => 0,
		     },
   dynamic_config => 1,
  );

$build->create_build_script;
