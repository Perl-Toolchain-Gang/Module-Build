#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use Test::More 'no_plan'; # tests => 35;


use File::Spec ();
my $common_pl = File::Spec->catfile( 't', 'common.pl' );
require $common_pl;


use Cwd ();
my $cwd = Cwd::cwd;
my $tmp = File::Spec->catdir( $cwd, 't', '_tmp' );

use DistGen;
my $dist = DistGen->new( dir => $tmp );
$dist->change_file( 'Build.PL', <<"---" );
use Module::Build;
my \$builder = Module::Build->new(
    module_name         => '@{[$dist->name]}',
    dist_version        => '3.14159265',
    license             => 'perl',
    create_readme       => 1,
);

\$builder->create_build_script();
---
$dist->regen;

chdir( $dist->dirname ) or die "Can't chdir to '@{[$dist->dirname]}': $!";

use Module::Build;
my $mb = Module::Build->new_from_context;
my $provides; # Used a bunch of times below

my $pod_text = <<'---'; 
=pod

=head1 NAME

Simple - A simple module 

=head1 AUTHOR

Simple Simon <simon@simple.sim>

=cut
---

sub _slurp {
    my $filename = shift;
    die "$filename doesn't exist. Aborting" if not -e $filename;
    open my $fh, "<", $filename
        or die "Couldn't open $filename: $!. Aborting.";
    local $/;
    return scalar <$fh>;
}

############################## Single Module
# .pm File with pod 
#

$dist->change_file( 'lib/Simple.pm', <<'---' . $pod_text);
package Simple;
$VERSION = '1.23';
---
$dist->regen( clean => 1 );
ok( -e "lib/Simple.pm", "Creating Simple.pm" );
$mb = Module::Build->new_from_context;
$mb->dispatch('distmeta');
like( _slurp("README"), qr/NAME/, 
    "Generating README from .pm");
is( $mb->dist_author->[0], 'Simple Simon <simon@simple.sim>', 
    "Extracting AUTHOR from .pm");
is( $mb->dist_abstract, "A simple module", 
    "Extracting abstract from .pm");

# .pm File with pod in separate file
#

$dist->change_file( 'lib/Simple.pm', <<'---');
package Simple;
$VERSION = '1.23';
---
$dist->change_file( 'lib/Simple.pod', $pod_text );
$dist->regen( clean => 1 );

ok( -e "lib/Simple.pm", "Creating Simple.pm" );
ok( -e "lib/Simple.pod", "Creating Simple.pod" );
$mb = Module::Build->new_from_context;
$mb->dispatch('distmeta');
like( _slurp("README"), qr/NAME/, "Generating README from .pod");
is( $mb->dist_author->[0], 'Simple Simon <simon@simple.sim>', 
    "Extracting AUTHOR from .pod");
is( $mb->dist_abstract, "A simple module", 
    "Extracting abstract from .pod");

# .pm File with pod and separate pod file 
#

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';

=pod

=head1 DONT USE THIS FILE FOR POD

=cut
---
$dist->change_file( 'lib/Simple.pod', $pod_text );
$dist->regen( clean => 1 );
ok( -e "lib/Simple.pm", "Creating Simple.pm" );
ok( -e "lib/Simple.pod", "Creating Simple.pod" );
$mb = Module::Build->new_from_context;
$mb->dispatch('distmeta');
like( _slurp("README"), qr/NAME/, "Generating README from .pod over .pm");
is( $mb->dist_author->[0], 'Simple Simon <simon@simple.sim>', 
    "Extracting AUTHOR from .pod over .pm");
is( $mb->dist_abstract, "A simple module", 
    "Extracting abstract from .pod over .pm");


############################################################
# cleanup
chdir( $cwd ) or die "Can't chdir to '$cwd': $!";
$dist->remove;

use File::Path;
rmtree( $tmp );
