use Module::Build; 

my $build = new Module::Build
  (
   module_name => 'Sample',
   scripts     => [ 'script', 'bin/sample.pl' ],
   license     => 'perl',
   requires    => { 'File::Spec' => 0 },
  );
$build->create_build_script;
