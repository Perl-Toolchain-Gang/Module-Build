use Module::Build;

my $build = new Module::Build 
  (
   module_name => 'Compress::Zlib',
   autosplit => 'lib/Compress/Zlib.pm',
   extra_linker_flags => '-L/usr/local/lib -lz',
  );

$build->create_build_script;
