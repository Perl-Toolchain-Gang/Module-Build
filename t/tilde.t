#!/usr/bin/perl -w

# Test ~ expansion from command line arguments.

use lib 't/lib';
use strict;

use Test::More tests => 6;

use TieOut;
use Cwd;
use File::Spec::Functions qw(catdir);
use Module::Build;

my $cwd = cwd;

sub test_tilde_expansion {
    my($args, $expect) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    chdir 'Sample';

    Module::Build->run_perl_script('Build.PL', [], [@$args, '--quiet=1']);

    my $mb = Module::Build->current;

    my $ret = like( $mb->install_destination('lib'), $expect,
                    join ' ', @$args
                  );

    chdir $cwd;

    return $ret;
}

{
    local $ENV{HOME} = 'home';
    test_tilde_expansion(['--install_base=~'],     qr{^$ENV{HOME}} );
    test_tilde_expansion(['--install_base=~/foo'], qr{^$ENV{HOME}/foo} );
    test_tilde_expansion(['--install_base=~~'],    qr{^~~} );
    test_tilde_expansion(['--install_base=foo~'],  qr{^foo~} );

    test_tilde_expansion(['--prefix=~'],           qr{^$ENV{HOME}} );

    test_tilde_expansion(['--install_path', 'lib=~/lib'], 
                                                   qr{^$ENV{HOME}/lib} );
}


