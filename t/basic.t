#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use Test::More tests => 52;


use File::Spec ();
my $common_pl = File::Spec->catfile( 't', 'common.pl' );
require $common_pl;


use Cwd ();
my $cwd = Cwd::cwd;

#########################


use_ok 'Module::Build';

like $INC{'Module/Build.pm'}, qr|/blib/|, "Make sure Module::Build was loaded from blib/";

chdir( 't' ) or die "Can't chdir to 't': $!";

# Test object creation
{
  my $build = new Module::Build( module_name => 'ModuleBuildOne' );
  ok $build;
  is $build->module_name, 'ModuleBuildOne';
  is $build->build_class, 'Module::Build';
  is $build->dist_name, 'ModuleBuildOne';
  
  $build = Module::Build->new( dist_name => 'ModuleBuildOne', dist_version => 7 );
  ok $build;
  is $build->module_name, '';  # Make sure it's defined
  is $build->dist_name, 'ModuleBuildOne';
}

# Make sure actions are defined, and known_actions works as class method
{
  my %actions = map {$_, 1} Module::Build->known_actions;
  ok $actions{clean};
  ok $actions{distdir};
}

# Test prerequisite checking
{
  local @INC = (@INC, 'lib');
  my $flagged = 0;
  local $SIG{__WARN__} = sub { $flagged = 1 if $_[0] =~ /ModuleBuildOne/};
  my $m = new Module::Build
    (
     module_name => 'ModuleBuildOne',
     requires => {ModuleBuildOne => 0},
    );
  ok !$flagged;
  ok !$m->prereq_failures;
  $m->dispatch('realclean');

  $flagged = 0;
  $m = new Module::Build
    (
     module_name => 'ModuleBuildOne',
     requires => {ModuleBuildOne => 3},
    );
  ok $flagged;
  ok $m->prereq_failures;
  ok $m->prereq_failures->{requires}{ModuleBuildOne};
  is $m->prereq_failures->{requires}{ModuleBuildOne}{have}, 0.01;
  is $m->prereq_failures->{requires}{ModuleBuildOne}{need}, 3;

  $m->dispatch('realclean');

  # Make sure check_installed_status() works as a class method
  my $info = Module::Build->check_installed_status('File::Spec', 0);
  ok $info->{ok};
  is $info->{have}, $File::Spec::VERSION;

  # Make sure check_installed_status() works with an advanced spec
  $info = Module::Build->check_installed_status('File::Spec', '> 0');
  ok $info->{ok};
  
  # Use 2 lines for this, to avoid a "used only once" warning
  local $Foo::Module::VERSION;
  $Foo::Module::VERSION = '1.01_02';

  $info = Module::Build->check_installed_status('Foo::Module', '1.01_02');
  ok $info->{ok};
  print "# $info->{message}\n" if $info->{message};
}

{
  # Make sure the correct warning message is generated when an
  # optional prereq isn't installed

  my $flagged = 0;
  local $SIG{__WARN__} = sub { $flagged = 1 if $_[0] =~ /ModuleBuildNonExistent isn't installed/};

  my $m = new Module::Build
    (
     module_name => 'ModuleBuildOne',
     recommends => {ModuleBuildNonExistent => 3},
    );
  ok $flagged;
}

# Test verbosity
{
  my $cwd = Cwd::cwd();

  chdir 'Sample';
  my $m = new Module::Build(module_name => 'Sample');

  $m->add_to_cleanup('save_out');
  # Use uc() so we don't confuse the current test output
  like uc(stdout_of( sub {$m->dispatch('test', verbose => 1)} )), qr/^OK 2/m;
  like uc(stdout_of( sub {$m->dispatch('test', verbose => 0)} )), qr/\.\.OK/;
  
  $m->dispatch('realclean');
  chdir $cwd or die "Can't change back to $cwd: $!";
}

# Make sure 'config' entries are respected on the command line, and that
# Getopt::Long specs work as expected.
{
  my $cwd = Cwd::cwd();
  use Config;
  
  chdir 'Sample';

  eval {Module::Build->run_perl_script('Build.PL', [], ['skip_rcfile=1', '--config', "foocakes=barcakes", '--foo', '--bar', '--bar', '-bat=hello', 'gee=whiz', '--any', 'hey', '--destdir', 'yo', '--verbose', '1'])};
  ok not $@;
  
  my $b = Module::Build->resume();
  is $b->config->{cc}, $Config{cc};
  is $b->config->{foocakes}, 'barcakes';

  # Test args().
  is $b->args('foo'), 1;
  is $b->args('bar'), 2, 'bar';
  is $b->args('bat'), 'hello', 'bat';
  is $b->args('gee'), 'whiz';
  is $b->args('any'), 'hey';
  is $b->args('dee'), 'goo';
  is $b->destdir, 'yo';
  is $b->runtime_params('destdir'), 'yo';
  is $b->runtime_params('verbose'), '1';
  ok not $b->runtime_params('license');
  ok my %runtime = $b->runtime_params;
  is scalar keys %runtime, 4;
  is $runtime{destdir}, 'yo';
  is $runtime{verbose}, '1';
  ok $runtime{config};

  ok my $argsref = $b->args;
  is $argsref->{foo}, 1;
  $argsref->{doo} = 'hee';
  is $b->args('doo'), 'hee';
  ok my %args = $b->args;
  is $args{foo}, 1;

  chdir $cwd or die "Can't change back to $cwd: $!";
}

# Test author stuff
{
  my $build = new Module::Build
    (
     module_name => 'ModuleBuildOne',
     dist_author => 'Foo Meister <foo@example.com>',
     build_class => 'My::Big::Fat::Builder',
    );
  ok $build;
  ok ref($build->dist_author);
  is $build->dist_author->[0], 'Foo Meister <foo@example.com>';
  is $build->build_class, 'My::Big::Fat::Builder';
}
