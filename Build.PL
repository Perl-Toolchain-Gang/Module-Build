use lib qw(lib);  # Use Module::Build to test & install itself
use Module::Build;

my $build = new Module::Build 
  (
   module_name => 'Module::Build',   
   prereq => {Config         => 0,
	      File::Copy     => 0,
	      File::Find     => 0,
	      File::Path     => 0,
	      File::Basename => 0,
	      File::Spec     => 0,
	      Data::Dumper   => 0,
	     },
  );

$build->create_build_script;
