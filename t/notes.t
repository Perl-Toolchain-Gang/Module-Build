#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use Test::More tests => 8;


use Cwd ();
my $cwd = Cwd::cwd;
my $tmp = File::Spec->catdir( $cwd, 't', '_tmp' );

use DistGen;
my $dist = DistGen->new( dir => $tmp );
$dist->regen;

chdir( $dist->dirname ) or die "Can't chdir to '@{[$dist->dirname]}': $!";


use Module::Build;

###################################
$dist->change_file( 'Build.PL', <<"---" );
use Module::Build;
my \$build = Module::Build->new(
  module_name => @{[$dist->name]},
  license     => 'perl'
);
\$build->create_build_script;
\$build->notes(foo => 'bar');
---

$dist->regen;

my $m = Module::Build->new_from_context;

is $m->notes('foo'), 'bar';

# Try setting & checking a new value
$m->notes(argh => 'new');
is $m->notes('argh'), 'new';

# Change existing value
$m->notes(foo => 'foo');
is $m->notes('foo'), 'foo';

# Change back so we can run this test again successfully
$m->notes(foo => 'bar');
is $m->notes('foo'), 'bar';

###################################
# Make sure notes set before create_build_script() get preserved
$m = Module::Build->new(module_name => $dist->name);
ok $m;
$m->notes(foo => 'bar');
is $m->notes('foo'), 'bar';

$m->create_build_script;

$m = Module::Build->resume;
ok $m;
is $m->notes('foo'), 'bar';


# cleanup
chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
$dist->remove;

use File::Path;
rmtree( $tmp );
