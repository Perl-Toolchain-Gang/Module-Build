use Module::Build;

my $build = new Module::Build
  (
   module_name => 'Sample',
   scripts     => [ 'script' ],
  );
$build->create_build_script;
