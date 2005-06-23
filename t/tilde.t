#!/usr/bin/perl -w

# Test ~ expansion from command line arguments.

use strict;

use Test::More tests => 2;

use Cwd;
use File::Spec::Functions qw(catdir);
use Module::Build;

my $cwd = cwd;

foreach my $param (qw(install_base prefix)) {
    local $ENV{HOME} = 'home';

    chdir 'Sample';
    Module::Build->run_perl_script('Build.PL', [], ["--$param=~"]);

    my $mb = Module::Build->current;

    like( $mb->install_destination('lib'), qr/\Q$ENV{HOME}/ );

    chdir $cwd;
}
