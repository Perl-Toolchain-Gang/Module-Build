use Module::Build;
use File::Spec;

my $build = new Module::Build 
  (
   module_name => 'XSTest',
   include_dirs => [ File::Spec->curdir ],
  );

$build->create_build_script;
