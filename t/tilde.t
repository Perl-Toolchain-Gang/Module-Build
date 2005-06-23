#!/usr/bin/perl -w

# Test ~ expansion from command line arguments.

use lib 't/lib';
use strict;

use Test::More tests => 10;

use TieOut;
use Cwd;
use File::Spec::Functions qw(catdir);
use Module::Build;

my $cwd = cwd;

sub run_sample {
    my($args) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    chdir 'Sample';

    Module::Build->run_perl_script('Build.PL', [], [@$args, '--quiet=1']);

    my $mb = Module::Build->current;

    chdir $cwd;
    
    return $mb;
}


{
    local $ENV{HOME} = 'home';

    my $mb;

    $mb = run_sample( ['--install_base=~']);
    is( $mb->install_base,      $ENV{HOME} );

    $mb = run_sample( ['--install_base=~/foo'], qr{^$ENV{HOME}/foo} );
    is( $mb->install_base,      "$ENV{HOME}/foo" );

    $mb = run_sample( ['--install_base=~~'] );
    is( $mb->install_base,      '~~' );

    $mb = run_sample( ['--install_base=foo~'] );
    is( $mb->install_base,      'foo~' );

    $mb = run_sample( ['--prefix=~'] );
    is( $mb->prefix,            $ENV{HOME} );

    $mb = run_sample( ['--install_path', 'html=~/html',
                       '--install_path', 'lib=~/lib'
                      ] );
    is( $mb->install_destination('lib'),  "$ENV{HOME}/lib" );
    is( $mb->install_destination('html'), "$ENV{HOME}/html" );

    $mb = run_sample( ['--install_path', 'lib=~/lib'] );
    is( $mb->install_destination('lib'),  "$ENV{HOME}/lib" );

    $mb = run_sample( ['--destdir=~'] );
    is( $mb->destdir,           $ENV{HOME} );

    $mb->install_base('~');
    is( $mb->install_base,      '~', 'API does not expand tildes' );
}
