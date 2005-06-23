#!/usr/bin/perl -w

# Test ~ expansion from command line arguments.

use lib 't/lib';
use strict;

use File::Spec ();
my $common_pl = File::Spec->catfile( 't', 'common.pl' );
require $common_pl;

use Test::More tests => 10;

use Module::Build;

use Cwd ();
my $cwd = Cwd::cwd;

use DistGen;
my $dist = DistGen->new;
$dist->regen;

chdir( $dist->dirname ) or die "Can't chdir to '@{[$dist->dirname]}': $!";

sub run_sample {
    my @args = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $dist->clean;

    my $mb;
    stdout_of( sub {
      $mb = Module::Build->new_from_context( @args );
    } );

    return $mb;
}


{
    local $ENV{HOME} = 'home';

    my $mb;

    $mb = run_sample( install_base => '~' );
    is( $mb->install_base,      $ENV{HOME} );

    $mb = run_sample( install_base => '~/foo' );
    is( $mb->install_base,      "$ENV{HOME}/foo" );

    $mb = run_sample( install_base => '~~' );
    is( $mb->install_base,      '~~' );

    $mb = run_sample( install_base => 'foo~' );
    is( $mb->install_base,      'foo~' );

    $mb = run_sample( prefix => '~' );
    is( $mb->prefix,            $ENV{HOME} );

    $mb = run_sample( install_path => { html => '~/html',
					lib  => '~/lib'   }
                    );
    is( $mb->install_destination('lib'),  "$ENV{HOME}/lib" );
    is( $mb->install_destination('html'), "$ENV{HOME}/html" );

    $mb = run_sample( install_path => { lib => '~/lib' } );
    is( $mb->install_destination('lib'),  "$ENV{HOME}/lib" );

    $mb = run_sample( destdir => '~' );
    is( $mb->destdir,           $ENV{HOME} );

    $mb->install_base('~');
    is( $mb->install_base,      '~', 'API does not expand tildes' );
}


chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
$dist->remove;