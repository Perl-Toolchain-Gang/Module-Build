use strict;
use Module::Build;

my $build = new Module::Build
  (
   module_name => 'B',
   module_version => 'a5',
   c_source => 'source',
  );

$build->create_build_script;
