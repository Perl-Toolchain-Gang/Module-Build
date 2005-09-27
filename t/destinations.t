#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use Test::More 'no_plan';   # tests => 68;


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


use Config;
use File::Spec::Functions qw( catdir splitdir );

#########################

use Module::Build;
my $mb = Module::Build->new_from_context;
isa_ok( $mb, 'Module::Build::Base' );

my $install_sets = $mb->install_sets;


# Get us into a known state.
$mb->installdirs('site');
$mb->install_base(undef);
$mb->prefix(undef);


# Check that we install into the proper default locations.
{
    is( $mb->installdirs, 'site' );
    is( $mb->install_base, undef );
    is( $mb->prefix,       undef );

    test_install_destinations( $mb, {
        lib     => $Config{installsitelib},
        arch    => $Config{installsitearch},
        bin     => $Config{installsitebin} || $Config{installbin},
        script  => $Config{installsitescript} || $Config{installsitebin} ||
                   $Config{installscript},
        bindoc  => $Config{installsiteman1dir} || $Config{installman1dir},
        libdoc  => $Config{installsiteman3dir} || $Config{installman3dir},
        binhtml => $Config{installsitehtml1dir} ||
		   $Config{installhtml1dir} || $Config{installhtmldir},
        libhtml => $Config{installsitehtml3dir} ||
		   $Config{installhtml3dir} || $Config{installhtmldir},
    });
}


# Is installdirs honored?
{
    $mb->installdirs('core');
    is( $mb->installdirs, 'core' );

    test_install_destinations( $mb, {
        lib     => $Config{installprivlib},
        arch    => $Config{installarchlib},
        bin     => $Config{installbin},
        script  => $Config{installscript} || $Config{installbin},
        bindoc  => $Config{installman1dir},
        libdoc  => $Config{installman3dir},
        binhtml => $Config{installhtml1dir} || $Config{installhtmldir},
        libhtml => $Config{installhtml3dir} || $Config{installhtmldir},
    });

    $mb->installdirs('site');
    is( $mb->installdirs, 'site' );
}


# Check install_base()
{
    my $install_base = catdir( 'foo', 'bar' );
    $mb->install_base( $install_base );

    is( $mb->prefix,       undef );
    is( $mb->install_base, $install_base );


    test_install_destinations( $mb, {
        lib     => catdir( $install_base, 'lib', 'perl5' ),
        arch    => catdir( $install_base, 'lib', 'perl5', $Config{archname} ),
        bin     => catdir( $install_base, 'bin' ),
        script  => catdir( $install_base, 'bin' ),
        bindoc  => catdir( $install_base, 'man', 'man1'),
        libdoc  => catdir( $install_base, 'man', 'man3' ),
        binhtml => catdir( $install_base, 'html' ),
        libhtml => catdir( $install_base, 'html' ),
    });
}


# Basic prefix test.  Ensure everything is under the prefix.
{
    $mb->install_base( undef );
    ok( !defined $mb->install_base );

    my $prefix = catdir( qw( some prefix ) );
    $mb->prefix( $prefix );
    is( $mb->{properties}{prefix}, $prefix );

    test_prefix($prefix, $install_sets->{site});
}


# And now that prefix honors installdirs.
{
    $mb->installdirs('core');
    is( $mb->installdirs, 'core' );

    my $prefix = catdir( qw( some prefix ) );
    test_prefix($prefix);

    $mb->installdirs('site');
    is( $mb->installdirs, 'site' );
}


# Try a config setting which would result in installation locations outside
# the prefix.  Ensure it doesn't.
{
    # Get the prefix defaults
    my $defaults = $mb->prefix_relpaths('site');

    # Create a configuration involving weird paths that are outside of
    # the configured prefix.
    my @prefixes = (
                    [qw(foo bar)],
                    [qw(biz)],
                    [],
                   );

    my %test_config;
    foreach my $type (keys %$defaults) {
        my $prefix = shift @prefixes || [qw(foo bar)];
        $test_config{$type} = catdir(File::Spec->rootdir, @$prefix, 
                                     @{$defaults->{$type}});
    }

    # Poke at the innards of MB to change the default install locations.
    local $mb->install_sets->{site} = \%test_config;
    $mb->config(siteprefixexp => catdir(File::Spec->rootdir, 
					'wierd', 'prefix'));

    my $prefix = catdir('another', 'prefix');
    $mb->prefix($prefix);
    test_prefix($prefix, \%test_config);
}


# Check that we can use install_base after setting prefix.
{
    my $install_base = catdir( 'foo', 'bar' );
    $mb->install_base( $install_base );

    test_install_destinations( $mb, {
        lib     => catdir( $install_base, 'lib', 'perl5' ),
        arch    => catdir( $install_base, 'lib', 'perl5', $Config{archname} ),
        bin     => catdir( $install_base, 'bin' ),
        script  => catdir( $install_base, 'bin' ),
        bindoc  => catdir( $install_base, 'man', 'man1'),
        libdoc  => catdir( $install_base, 'man', 'man3' ),
        binhtml => catdir( $install_base, 'html' ),
        libhtml => catdir( $install_base, 'html' ),
    });
}


sub test_prefix {
    my ($prefix, $test_config) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    foreach my $type (qw(lib arch bin script bindoc libdoc binhtml libhtml)) {
        my $dest = $mb->install_destination( $type );
        like( $dest, "/^\Q$prefix\E/", "$type prefixed");

        if( $test_config && $test_config->{$type} ) {
            my @dest_dirs = splitdir( $dest );
            my @test_dirs = splitdir( $test_config->{$type} );

            is( $dest_dirs[-1], $test_dirs[-1], "  suffix correctish ($dest vs $test_config->{$type})" );
        }
    }
}


sub test_install_destinations {
    my($build, $expect) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    while( my($type, $expect) = each %$expect ) {
        is( $build->install_destination($type), $expect, "$type destination" );
    }
}


chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
$dist->remove;

use File::Path;
rmtree( $tmp );
