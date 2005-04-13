use strict;

use File::Spec;
BEGIN {
  my $common_pl = File::Spec->catfile('t', 'common.pl');
  require $common_pl;
}
use Test::More (tests => 34);

use Module::Build;
use File::Path;
use Config;


my $start_dir = Module::Build->cwd;

# Would be nice to just have a 'base_dir' parameter for M::B->new()
my $goto = File::Spec->catdir( $start_dir, 't', 'Sample' );
chdir $goto or die "can't chdir to $goto: $!";


my $build = new Module::Build( module_name => 'Sample',
			       script_files => [ 'script' ],
			       requires => { 'File::Spec' => 0 },
			       license => 'perl' );
ok $build;


my $destdir = File::Spec->catdir($start_dir, 't', 'install_test');
$build->add_to_cleanup($destdir);

{
  eval {$build->dispatch('install', destdir => $destdir)};
  is $@, '';
  
  my $libdir = strip_volume( $build->install_destination('lib') );
  my $install_to = File::Spec->catfile($destdir, $libdir, 'Sample.pm');
  print "Should have installed module as $install_to\n";
  ok -e $install_to;
  
  local @INC = (@INC, File::Spec->catdir($destdir, $libdir));
  eval {require Sample};
  is $@, '';
  
  # Make sure there's a packlist installed
  my $archdir = $build->install_destination('arch');
  my ($v, $d) = File::Spec->splitpath($archdir, 1);
  my $packlist = File::Spec->catdir($destdir, $d, 'auto', 'Sample', '.packlist');
  is -e $packlist, 1, "$packlist should be written";
}

{
  eval {$build->dispatch('install', installdirs => 'core', destdir => $destdir)};
  is $@, '';
  my $libdir = strip_volume( $Config{installprivlib} );
  my $install_to = File::Spec->catfile($destdir, $libdir, 'Sample.pm');
  print "Should have installed module as $install_to\n";
  ok -e $install_to;
}

{
  my $libdir = File::Spec->catdir(File::Spec->rootdir, 'foo', 'bar');
  eval {$build->dispatch('install', install_path => {lib => $libdir}, destdir => $destdir)};
  is $@, '';
  my $install_to = File::Spec->catfile($destdir, $libdir, 'Sample.pm');
  print "Should have installed module as $install_to\n";
  ok -e $install_to;
}

{
  my $libdir = File::Spec->catdir(File::Spec->rootdir, 'foo', 'base');
  eval {$build->dispatch('install', install_base => $libdir, destdir => $destdir)};
  is $@, '';
  my $install_to = File::Spec->catfile($destdir, $libdir, 'lib', 'perl5', 'Sample.pm');
  print "Should have installed module as $install_to\n";
  ok -e $install_to;  
}

{
  # Test the ConfigData stuff
  
  $build->config_data(foo => 'bar');
  $build->features(baz => 1);
  $build->auto_features(auto_foo => {requires => {'File::Spec' => 0}});
  eval {$build->dispatch('install', destdir => $destdir)};
  is $@, '';
  
  my $libdir = strip_volume( $build->install_destination('lib') );
  local @INC = (@INC, File::Spec->catdir($destdir, $libdir));
  eval {require Sample::ConfigData};

  is $build->feature('auto_foo'), 1;
  
 SKIP:
  {
    skip $@, 5 if @_;

    # Make sure the values are present
    is( Sample::ConfigData->config('foo'), 'bar' );
    ok( Sample::ConfigData->feature('baz') );
    ok( Sample::ConfigData->feature('auto_foo') );
    ok( not Sample::ConfigData->feature('nonexistent') );

    # Add a new value to the config set
    Sample::ConfigData->set_config(floo => 'bhlar');
    is( Sample::ConfigData->config('floo'), 'bhlar' );

    # Make sure it actually got written
    Sample::ConfigData->write;
    delete $INC{'Sample/ConfigData.pm'};
    {
      local $^W;  # Avoid warnings for subroutine redefinitions
      require Sample::ConfigData;
    }
    is( Sample::ConfigData->config('floo'), 'bhlar' );
  }
}


eval {$build->dispatch('realclean')};
is $@, '';

{
  # Try again by running the script rather than with programmatic interface
  my $libdir = File::Spec->catdir('', 'foo', 'lib');
  eval {$build->run_perl_script('Build.PL', [], ['--install_path', "lib=$libdir"])};
  is $@, '';
  
  eval {$build->run_perl_script('Build', [], ['install', '--destdir', $destdir])};
  is $@, '';
  my $install_to = File::Spec->catfile($destdir, $libdir, 'Sample.pm');
  print "# Should have installed module as $install_to\n";
  ok -e $install_to;

  my $basedir = File::Spec->catdir('', 'bar');
  eval {$build->run_perl_script('Build', [], ['install', '--destdir', $destdir,
					      '--install_base', $basedir])};
  is $@, '';
  
  $install_to = File::Spec->catfile($destdir, $libdir, 'Sample.pm');
  is -e $install_to, 1, "Look for file at $install_to";
  
  eval {$build->dispatch('realclean')};
  is $@, '';
}

{
  # Make sure 'install_path' overrides 'install_base'
  my $build = Module::Build->new( module_name => 'Sample',
				  install_base => File::Spec->catdir('', 'foo'),
				  install_path => {lib => File::Spec->catdir('', 'bar')});
  ok $build;
  is $build->install_destination('lib'), File::Spec->catdir('', 'bar');
}

{
  # _find_file_by_type() isn't a public method, but this is currently
  # the only easy way to test that it works properly.
  my $pods = $build->_find_file_by_type('pod', 'lib');
  is keys %$pods, 1;
  my $expect = $build->localize_file_path('lib/Sample/Docs.pod');
  is $pods->{$expect}, $expect;
  
  my $pms = $build->_find_file_by_type('awefawef', 'lib');
  ok $pms;
  is keys %$pms, 0;
  
  $pms = $build->_find_file_by_type('pod', 'awefawef');
  ok $pms;
  is keys %$pms, 0;
}

sub strip_volume {
  my $dir = shift;
  (undef, $dir) = File::Spec->splitpath( $dir, 1 );
  return $dir;
}

