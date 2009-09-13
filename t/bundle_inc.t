# sample.t -- a sample test file for Module::Build

use strict;
use lib $ENV{PERL_CORE} ? '../lib/Module/Build/t/lib' : 't/lib';
use MBTest; # or 'no_plan'
use DistGen;
use File::Spec;

plan tests => 7;

# Ensure any Module::Build modules are loaded from correct directory
blib_load('Module::Build');

# create dist object in a temp directory
# enter the directory and generate the skeleton files
my $dist = DistGen->new( inc => 1 )->chdir_in->regen;

# get a Module::Build object and test with it
my $mb = $dist->new_from_context(); # quiet by default
isa_ok( $mb, "Module::Build" );
is( $mb->dist_name, "Simple", "dist_name is 'Simple'" );
is_deeply( $mb->bundle_inc, [ 'Module::Build' ],
  "Module::Build is flagged for bundling"
);

# see what gets bundled
my $dist_inc = File::Spec->catdir($mb->dist_dir, 'inc');
stdout_stderr_of( sub { $mb->dispatch('distdir') } );
ok( -e File::Spec->catfile( $dist_inc, 'latest.pm' ), 
  "./inc/latest.pm created"
);

ok( -d File::Spec->catdir( $dist_inc, 'inc_Module-Build' ),
  "./inc/inc_Module_Build created"
);

ok( -e File::Spec->catfile( $dist_inc, qw/inc_Module-Build Module Build.pm/ ),
  "./inc/inc_Module_Build/Module/Build.pm created"
);

ok( -e File::Spec->catfile( $dist_inc, qw/inc_Module-Build Module Build Base.pm/ ),
  "./inc/inc_Module_Build/Module/Build/Base.pm created"
);


# vim:ts=2:sw=2:et:sta:sts=2
