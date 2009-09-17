# sample.t -- a sample test file for Module::Build

use strict;
use lib $ENV{PERL_CORE} ? '../lib/Module/Build/t/lib' : 't/lib';
use MBTest; # or 'no_plan'
use DistGen;
use IO::File;
use File::Spec;

plan tests => 8;

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
stdout_stderr_of( sub { $mb->dispatch('distdir') } );

my $dist_inc = File::Spec->catdir($mb->dist_dir, 'inc');
ok( -e File::Spec->catfile( $dist_inc, 'latest.pm' ), 
  "./inc/latest.pm created"
);

ok( -d File::Spec->catdir( $dist_inc, 'inc_Module-Build' ),
  "dist_dir/inc/inc_Module_Build created"
);

my $mb_file = 
  File::Spec->catfile( $dist_inc, qw/inc_Module-Build Module Build.pm/ );

ok( -e $mb_file,
  "dist_dir/inc/inc_Module_Build/Module/Build.pm created"
);

ok( -e File::Spec->catfile( $dist_inc, qw/inc_Module-Build Module Build Base.pm/ ),
  "dist_dir/inc/inc_Module_Build/Module/Build/Base.pm created"
);

# Force bundled M::B to a higher version so it gets loaded

my $fh = IO::File->new($mb_file, "+<") or die "Could not open $mb_file: $!";
my $mb_code = do { local $/; <$fh> };
$mb_code =~ s{\$VERSION\s+=\s+\S+}{\$VERSION = 9999;};
$fh->seek(0,0);
print {$fh} $mb_code;
$fh->close;

# test the bundling in dist_dir
chdir $mb->dist_dir;

stdout_of( sub { Module::Build->run_perl_script('Build.PL',[],[]) } );

my $meta = IO::File->new('MYMETA.yml');
ok( scalar( grep { /generated_by:.*9999/ } <$meta> ),
  "dist_dir Build.PL loaded bundled Module::Build"
);


# vim:ts=2:sw=2:et:sta:sts=2
