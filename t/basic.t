#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use Test::More tests => 52;


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


use_ok 'Module::Build';

like $INC{'Module/Build.pm'}, qr/\bblib\b/, "Make sure Module::Build was loaded from blib/";


# Test object creation
{
  my $m = Module::Build->new( module_name => $dist->name );
  ok $m;
  is $m->module_name, $dist->name;
  is $m->build_class, 'Module::Build';
  is $m->dist_name, $dist->name;

  $m = Module::Build->new( dist_name => $dist->name, dist_version => 7 );
  ok $m;
  ok ! $m->module_name;  # Make sure it's defined
  is $m->dist_name, $dist->name;
}

# Make sure actions are defined, and known_actions works as class method
{
  my %actions = map {$_, 1} Module::Build->known_actions;
  ok $actions{clean};
  ok $actions{distdir};
}

# Test prerequisite checking
{
  local @INC = (File::Spec->catdir( $dist->dirname, 'lib' ), @INC);
  my $flagged = 0;
  local $SIG{__WARN__} = sub { $flagged = 1 if $_[0] =~ /@{[$dist->name]}/};
  my $m = Module::Build->new(
    module_name => $dist->name,
    requires    => {$dist->name => 0},
  );
  ok ! $flagged;
  ok ! $m->prereq_failures;
  $m->dispatch('realclean');
  $dist->clean;

  $flagged = 0;
  $m = Module::Build->new(
    module_name => $dist->name,
    requires    => {$dist->name => 3.14159265},
  );
  ok $flagged;
  ok $m->prereq_failures;
  ok $m->prereq_failures->{requires}{$dist->name};
  is $m->prereq_failures->{requires}{$dist->name}{have}, 0.01;
  is $m->prereq_failures->{requires}{$dist->name}{need}, 3.14159265;

  $m->dispatch('realclean');
  $dist->clean;

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

  my $m = Module::Build->new(
    module_name => $dist->name,
    recommends  => {ModuleBuildNonExistent => 3},
  );
  ok $flagged;
  $dist->clean;
}

# Test verbosity
{
  my $m = Module::Build->new(module_name => $dist->name);

  $m->add_to_cleanup('save_out');
  # Use uc() so we don't confuse the current test output
  like uc(stdout_of( sub {$m->dispatch('test', verbose => 1)} )), qr/^OK \d/m;
  like uc(stdout_of( sub {$m->dispatch('test', verbose => 0)} )), qr/\.\.OK/;

  $m->dispatch('realclean');
  $dist->clean;
}

# Make sure 'config' entries are respected on the command line, and that
# Getopt::Long specs work as expected.
{
  use Config;
  $dist->change_file( 'Build.PL', <<"---" );
use Module::Build;

my \$build = Module::Build->new(
  module_name => @{[$dist->name]},
  license     => 'perl',
  get_options => { foo => {},
                   bar => { type    => '+'  },
                   bat => { type    => '=s' },
                   dee => { type    => '=s',
                            default => 'goo'
                          },
                 }
);

\$build->create_build_script;
---

  $dist->regen;
  eval {Module::Build->run_perl_script('Build.PL', [], ['skip_rcfile=1', '--config', "foocakes=barcakes", '--foo', '--bar', '--bar', '-bat=hello', 'gee=whiz', '--any', 'hey', '--destdir', 'yo', '--verbose', '1'])};
  ok ! $@;

  my $m = Module::Build->resume;
  is $m->config->{cc}, $Config{cc};
  is $m->config->{foocakes}, 'barcakes';

  # Test args().
  is $m->args('foo'), 1;
  is $m->args('bar'), 2, 'bar';
  is $m->args('bat'), 'hello', 'bat';
  is $m->args('gee'), 'whiz';
  is $m->args('any'), 'hey';
  is $m->args('dee'), 'goo';
  is $m->destdir, 'yo';
  is $m->runtime_params('destdir'), 'yo';
  is $m->runtime_params('verbose'), '1';
  ok ! $m->runtime_params('license');
  ok my %runtime = $m->runtime_params;
  is scalar keys %runtime, 4;
  is $runtime{destdir}, 'yo';
  is $runtime{verbose}, '1';
  ok $runtime{config};

  ok my $argsref = $m->args;
  is $argsref->{foo}, 1;
  $argsref->{doo} = 'hee';
  is $m->args('doo'), 'hee';
  ok my %args = $m->args;
  is $args{foo}, 1;

  # revert test distribution to pristine state because we modified a file
  chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
  $dist->remove;
  $dist = DistGen->new( dir => $tmp );
  $dist->regen;
  chdir( $dist->dirname ) or die "Can't chdir to '@{[$dist->dirname]}': $!";
}

# Test author stuff
{
  my $m = Module::Build->new(
    module_name => $dist->name,
    dist_author => 'Foo Meister <foo@example.com>',
    build_class => 'My::Big::Fat::Builder',
  );
  ok $m;
  ok ref($m->dist_author), 'dist_author converted to array if simple string';
  is $m->dist_author->[0], 'Foo Meister <foo@example.com>';
  is $m->build_class, 'My::Big::Fat::Builder';
}


# cleanup
chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
$dist->remove;

use File::Path;
rmtree( $tmp );
