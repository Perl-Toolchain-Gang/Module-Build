use lib qw(lib);  # Use Module::Build to test & install itself
use Module::Build;

my $build = new Module::Build 
  (
   module_name => 'Module::Build',   
  );

$build->create_build_script;
