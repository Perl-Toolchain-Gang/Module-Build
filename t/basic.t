######################### We start with some black magic to print on failure.

use strict;
use Test;
BEGIN { plan tests => 46 }
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
  
  # Use 2 lines for this, to avoid a "used only once" warning
  local $Foo::Module::VERSION;
  $Foo::Module::VERSION = '1.01_02';

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

# Make sure 'config' entries are respected on the command line, and that
# Getopt::Long specs work as expected.
{
  my $cwd = Cwd::cwd();
  use Config;
  
  chdir 'Sample';

  eval {Module::Build->run_perl_script('Build.PL', [], ['--config', "foocakes=barcakes", '--foo', '--bar', '--bar', '-bat=hello', 'gee=whiz', '--any', 'hey'])};
  ok $@, '';
  
  my $b = Module::Build->resume();
  ok $b->config->{cc}, $Config{cc};
  ok $b->config->{foocakes}, 'barcakes';

  # Test args().
  ok $b->args('foo'), 1;
  ok $b->args('bar'), 2, 'bar';
  ok $b->args('bat'), 'hello', 'bat';
  ok $b->args('gee'), 'whiz';
  ok $b->args('any'), 'hey';
  ok $b->args('dee'), 'goo';

  ok my $argsref = $b->args;
  ok $argsref->{foo}, 1;
  $argsref->{doo} = 'hee';
  ok $b->args('doo'), 'hee';
  ok my %args = $b->args;
  ok $args{foo}, 1;

  chdir $cwd or die "Can't change back to $cwd: $!";
}

# Test author stuff
{
  my $build = new Module::Build
    (
     module_name => 'ModuleBuildOne',
     dist_author => 'Foo Meister <foo@example.com>',
    );
  ok $build;
  ok ref($build->dist_author);
  ok $build->dist_author->[0], 'Foo Meister <foo@example.com>';
}

# Test shell emulation stuff
{
  my @words = Module::Build->split_like_shell(q{one t'wo th'ree f"o\"ur " "five" });
  ok @words, 4;
  ok $words[0], 'one';
  ok $words[1], 'two three';
  ok $words[2], 'fo"ur ';
  ok $words[3], 'five';

  # Test some Win32-specific stuff
  my $win = 'Module::Build::Platform::Windows';
  eval "use $win; 1" or die $@;
  
  @words = $win->split_like_shell(q{foo "\bar\baz" "b\"nai"});
  ok @words, 3;
  ok $words[0], 'foo';
  ok $words[1], '\bar\baz';
  ok $words[2], 'b"nai';
}
