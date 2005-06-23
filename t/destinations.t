#!/usr/bin/perl -w

use strict;

use Config;
use File::Spec::Functions qw( catdir splitdir );

use File::Spec;

BEGIN {
  my $common_pl = File::Spec->catfile('t', 'common.pl');
  require $common_pl;
}


use Test::More tests => 67;

use_ok 'Module::Build';


my $M = Module::Build->current;
isa_ok( $M, 'Module::Build::Base' );

my $Install_Sets = $M->install_sets;


# Get us into a known state.
$M->installdirs('site');
$M->install_base(undef);
$M->prefix(undef);


# Check that we install into the proper default locations.
{
    is( $M->installdirs, 'site' );
    is( $M->install_base, undef );
    is( $M->prefix,       undef );

    test_install_destinations( $M, {
        lib     => $Config{installsitelib},
        arch    => $Config{installsitearch},
        bin     => $Config{installsitebin} || $Config{installbin},
        script  => $Config{installsitescript} || $Config{installsitebin} ||
                   $Config{installscript},
        bindoc  => $Config{installsiteman1dir} || $Config{installman1dir},
        libdoc  => $Config{installsiteman3dir} || $Config{installman3dir}
    });
}


# Is installdirs honored?
{
    $M->installdirs('core');
    is( $M->installdirs, 'core' );

    test_install_destinations( $M, {
        lib     => $Config{installprivlib},
        arch    => $Config{installarchlib},
        bin     => $Config{installbin},
        script  => $Config{installscript} || $Config{installbin},
        bindoc  => $Config{installman1dir},
        libdoc  => $Config{installman3dir},
    });

    $M->installdirs('site');
    is( $M->installdirs, 'site' );
}


# Check install_base()
{
    my $install_base = catdir( 'foo', 'bar' );
    $M->install_base( $install_base );

    is( $M->prefix,       undef );
    is( $M->install_base, $install_base );


    test_install_destinations( $M, {
        lib     => catdir( $install_base, 'lib', 'perl5' ),
        arch    => catdir( $install_base, 'lib', 'perl5', $Config{archname} ),
        bin     => catdir( $install_base, 'bin' ),
        script  => catdir( $install_base, 'bin' ),
        bindoc  => catdir( $install_base, 'man', 'man1'),
        libdoc  => catdir( $install_base, 'man', 'man3' ),
    });
}


# Basic prefix test.  Ensure everything is under the prefix.
{
    $M->install_base( undef );
    ok( !defined $M->install_base );

    my $prefix = catdir( qw( some prefix ) );
    $M->prefix( $prefix );
    is( $M->{properties}{prefix}, $prefix );

    test_prefix($prefix, $Install_Sets->{site});
}


# And now that prefix honors installdirs.
{
    $M->installdirs('core');
    is( $M->installdirs, 'core' );

    my $prefix = catdir( qw( some prefix ) );
    test_prefix($prefix);

    $M->installdirs('site');
    is( $M->installdirs, 'site' );
}


# Try a config setting which would result in installation locations outside
# the prefix.  Ensure it doesn't.
{
    # Get the prefix defaults
    my $defaults = $M->prefix_relpaths('site');

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
                                     $defaults->{$type});
    }

    # Poke at the innards of MB to change the default install locations.
    while( my($key, $path) = each %test_config ) {
        $M->{properties}{install_sets}{site}{$key} = $path;
    }

    $M->{config}{siteprefixexp} = catdir(File::Spec->rootdir, 
                                         'wierd', 'prefix');

    my $prefix = catdir('another', 'prefix');
    $M->prefix($prefix);
    test_prefix($prefix, \%test_config);
}


# Check that we can use install_base after setting prefix.
{
    my $install_base = catdir( 'foo', 'bar' );
    $M->install_base( $install_base );

    test_install_destinations( $M, {
        lib     => catdir( $install_base, 'lib', 'perl5' ),
        arch    => catdir( $install_base, 'lib', 'perl5', $Config{archname} ),
        bin     => catdir( $install_base, 'bin' ),
        script  => catdir( $install_base, 'bin' ),
        bindoc  => catdir( $install_base, 'man', 'man1'),
        libdoc  => catdir( $install_base, 'man', 'man3' ),
    });
}


sub test_prefix {
    my ($prefix, $test_config) = @_;
  
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    foreach my $type (qw(lib arch bin script bindoc libdoc)) {
        my $dest = $M->install_destination( $type );
        like( $dest, "/^\Q$prefix\E/", "$type prefixed");

        if( $test_config ) {
            my @test_dirs = splitdir( $test_config->{$type} );
            my @dest_dirs = splitdir( $dest );

            is( $dest_dirs[-1], $test_dirs[-1], '  suffix correctish' );
        }
            
    }
}


sub test_install_destinations {
    my($mb, $expect) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    while( my($type, $expect) = each %$expect ) {
        is( $mb->install_destination($type), $expect, "$type destination" );
    }
}
