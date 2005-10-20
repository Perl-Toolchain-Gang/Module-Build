#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use Test::More tests => 34;


use File::Spec ();
my $common_pl = File::Spec->catfile( 't', 'common.pl' );
require $common_pl;


use Cwd ();
my $cwd = Cwd::cwd;
my $tmp = File::Spec->catdir( $cwd, 't', '_tmp' );

use DistGen;
my $dist = DistGen->new( dir => $tmp );
$dist->regen;

chdir( $dist->dirname ) or die "Can't chdir to '@{[$dist->dirname]}': $!";

#########################

use Module::Build;
use Config;


$dist->add_file( 'script', <<'---' );
#!perl -w
print "Hello, World!\n";
---
$dist->change_file( 'Build.PL', <<"---" );
use Module::Build;

my \$build = new Module::Build(
  module_name => @{[$dist->name]},
  scripts     => [ 'script' ],
  license     => 'perl',
  requires    => { 'File::Spec' => 0 },
);
\$build->create_build_script;
---
$dist->regen;

my $mb = Module::Build->new_from_context( use_rcfile => 0 );
ok $mb;


my $destdir = File::Spec->catdir($cwd, 't', 'install_test');
$mb->add_to_cleanup($destdir);

{
  eval {$mb->dispatch('install', destdir => $destdir)};
  is $@, '';
  
  my $libdir = strip_volume( $mb->install_destination('lib') );
  my $install_to = File::Spec->catfile($destdir, $libdir, $dist->name ) . '.pm';
  print "Should have installed module as $install_to\n";
  ok -e $install_to;
  
  local @INC = (@INC, File::Spec->catdir($destdir, $libdir));
  eval "require @{[$dist->name]}";
  is $@, '';
  
  # Make sure there's a packlist installed
  my $archdir = $mb->install_destination('arch');
  my ($v, $d) = File::Spec->splitpath($archdir, 1);
  my $packlist = File::Spec->catdir($destdir, $d, 'auto', $dist->name, '.packlist');
  is -e $packlist, 1, "$packlist should be written";
}

{
  eval {$mb->dispatch('install', installdirs => 'core', destdir => $destdir)};
  is $@, '';
  my $libdir = strip_volume( $Config{installprivlib} );
  my $install_to = File::Spec->catfile($destdir, $libdir, $dist->name ) . '.pm';
  print "Should have installed module as $install_to\n";
  ok -e $install_to;
}

{
  my $libdir = File::Spec->catdir(File::Spec->rootdir, 'foo', 'bar');
  eval {$mb->dispatch('install', install_path => {lib => $libdir}, destdir => $destdir)};
  is $@, '';
  my $install_to = File::Spec->catfile($destdir, $libdir, $dist->name ) . '.pm';
  print "Should have installed module as $install_to\n";
  ok -e $install_to;
}

{
  my $libdir = File::Spec->catdir(File::Spec->rootdir, 'foo', 'base');
  eval {$mb->dispatch('install', install_base => $libdir, destdir => $destdir)};
  is $@, '';
  my $install_to = File::Spec->catfile($destdir, $libdir, 'lib', 'perl5', $dist->name ) . '.pm';
  print "Should have installed module as $install_to\n";
  ok -e $install_to;
}

{
  # Test the ConfigData stuff
  
  $mb->config_data(foo => 'bar');
  $mb->features(baz => 1);
  $mb->auto_features(auto_foo => {requires => {'File::Spec' => 0}});
  eval {$mb->dispatch('install', destdir => $destdir)};
  is $@, '';
  
  my $libdir = strip_volume( $mb->install_destination('lib') );
  local @INC = (@INC, File::Spec->catdir($destdir, $libdir));
  eval "require @{[$dist->name]}::ConfigData";

  is $mb->feature('auto_foo'), 1;
  
  SKIP: {
    skip $@, 5 if @_;

    # Make sure the values are present
    my $config = $dist->name . '::ConfigData';
    is( $config->config('foo'), 'bar' );
    ok( $config->feature('baz') );
    ok( $config->feature('auto_foo') );
    ok( not $config->feature('nonexistent') );

    # Add a new value to the config set
    $config->set_config(floo => 'bhlar');
    is( $config->config('floo'), 'bhlar' );

    # Make sure it actually got written
    $config->write;
    delete $INC{"@{[$dist->name]}/ConfigData.pm"};
    {
      local $^W;  # Avoid warnings for subroutine redefinitions
      eval "require $config";
    }
    is( $config->config('floo'), 'bhlar' );
  }
}


eval {$mb->dispatch('realclean')};
is $@, '';

{
  # Try again by running the script rather than with programmatic interface
  my $libdir = File::Spec->catdir('', 'foo', 'lib');
  eval {$mb->run_perl_script('Build.PL', [], ['--install_path', "lib=$libdir"])};
  is $@, '';
  
  eval {$mb->run_perl_script('Build', [], ['install', '--destdir', $destdir])};
  is $@, '';
  my $install_to = File::Spec->catfile($destdir, $libdir, $dist->name ) . '.pm';
  print "# Should have installed module as $install_to\n";
  ok -e $install_to;

  my $basedir = File::Spec->catdir('', 'bar');
  eval {$mb->run_perl_script('Build', [], ['install', '--destdir', $destdir,
					      '--install_base', $basedir])};
  is $@, '';
  
  $install_to = File::Spec->catfile($destdir, $libdir, $dist->name ) . '.pm';
  is -e $install_to, 1, "Look for file at $install_to";
  
  eval {$mb->dispatch('realclean')};
  is $@, '';
}

{
  # Make sure 'install_path' overrides 'install_base'
  my $mb = Module::Build->new( module_name => $dist->name,
				  install_base => File::Spec->catdir('', 'foo'),
				  install_path => {lib => File::Spec->catdir('', 'bar')});
  ok $mb;
  is $mb->install_destination('lib'), File::Spec->catdir('', 'bar');
}

{
  $dist->add_file( 'lib/Simple/Docs.pod', <<'---' );
=head1 NAME

Simple::Docs - Simple pod

=head1 AUTHOR

Simple Man <simple@example.com>

=cut
---
  $dist->regen;

  # _find_file_by_type() isn't a public method, but this is currently
  # the only easy way to test that it works properly.
  my $pods = $mb->_find_file_by_type('pod', 'lib');
  is keys %$pods, 1;
  my $expect = $mb->localize_file_path('lib/Simple/Docs.pod');
  is $pods->{$expect}, $expect;
  
  my $pms = $mb->_find_file_by_type('awefawef', 'lib');
  ok $pms;
  is keys %$pms, 0;
  
  $pms = $mb->_find_file_by_type('pod', 'awefawef');
  ok $pms;
  is keys %$pms, 0;

  # revert to pristine state
  chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
  $dist->remove;
  $dist = DistGen->new( dir => $tmp );
  $dist->regen;
  chdir( $dist->dirname ) or die "Can't chdir to '@{[$dist->dirname]}': $!";
}

sub strip_volume {
  my $dir = shift;
  (undef, $dir) = File::Spec->splitpath( $dir, 1 );
  return $dir;
}


# cleanup
chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
$dist->remove;

use File::Path;
rmtree( $tmp );
