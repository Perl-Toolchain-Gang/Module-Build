use Module::Build;

my $build = new Module::Build
  (
   module_name => 'Sample',
  );
$build->create_build_script;
