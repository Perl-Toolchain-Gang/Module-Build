######################### We start with some black magic to print on failure.

use strict;
use Test;
BEGIN { plan tests => 20 }
use Module::Build;
ok(1);

use File::Spec;
use Cwd;
require File::Spec->catfile('t', 'common.pl');

######################### End of black magic.

ok $INC{'Module/Build.pm'}, '/blib/', "Make sure Module::Build was loaded from blib/";

chdir 't';

# Test object creation
{
  my $build = new Module::Build
    (
     module_name => 'ModuleBuildOne',
    );
  ok $build;
  ok $build->module_name, 'ModuleBuildOne';
}

# Make sure actions are defined, and known_actions works as class method
{
  my %actions = map {$_, 1} Module::Build->known_actions;
  ok $actions{clean}, 1;
  ok $actions{distdir}, 1;
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
  ok $flagged, 0;
  ok !$m->prereq_failures;
  $m->dispatch('realclean');

  $flagged = 0;
  $m = new Module::Build
    (
     module_name => 'ModuleBuildOne',
     requires => {ModuleBuildOne => 3},
    );
  ok $flagged, 1;
  ok $m->prereq_failures;
  ok $m->prereq_failures->{requires}{ModuleBuildOne};
  ok $m->prereq_failures->{requires}{ModuleBuildOne}{have}, 0.01;
  ok $m->prereq_failures->{requires}{ModuleBuildOne}{need}, 3;

  $m->dispatch('realclean');

  # Make sure check_installed_status() works as a class method
  my $info = Module::Build->check_installed_status('File::Spec', 0);
  ok $info->{ok}, 1;
  ok $info->{have}, $File::Spec::VERSION;

  # Make sure check_installed_status() works with an advanced spec
  $info = Module::Build->check_installed_status('File::Spec', '> 0');
  ok $info->{ok}, 1;
  
  local $Foo::Module::VERSION = '1.01_02';
  $info = Module::Build->check_installed_status('Foo::Module', '1.01_02');
  ok $info->{ok}, 1;
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
  ok uc(stdout_of( sub {$m->dispatch('test', verbose => 1)} )), qr/^OK 2/m;
  ok uc(stdout_of( sub {$m->dispatch('test', verbose => 0)} )), qr/\.\.OK/;
  
  $m->dispatch('realclean');
  chdir $cwd or die "Can't change back to $cwd: $!";
}

# Make sure 'config' entries are respected on the command line
{
  my $cwd = Cwd::cwd();
  
  chdir 'Sample';
  eval {$build->run_perl_script('Build.PL', [], ['--config', "foocakes=barcakes"])};
  ok $@, '';
  
  my $b = Module::Build->resume();
  ok $b->config->{foocakes}, 'barcakes';
}
