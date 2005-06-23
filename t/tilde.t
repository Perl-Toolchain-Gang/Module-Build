#!/usr/bin/perl -w

# Test ~ expansion from command line arguments.

use strict;

use Test::More tests => 1;

use Cwd;
use File::Spec::Functions qw(catdir);
use Module::Build;

my $cwd = cwd;

{
    local $ENV{HOME} = 'home';

    chdir 'Sample';
    Module::Build->run_perl_script('Build.PL', [], ['--install_base=~']);

    my $mb = Module::Build->current;

    like( $mb->install_destination('lib'), qr/^$ENV{HOME}/ );

    chdir $cwd;
}
