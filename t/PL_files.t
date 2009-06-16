#!/usr/bin/perl -w

use strict;
use lib $ENV{PERL_CORE} ? '../lib/Module/Build/t/lib' : 't/lib';
use MBTest tests => 6;
use DistGen;
use Module::Build;


# Set up a distribution for testing
my $dist;
{
    $dist = DistGen->new( dir => MBTest->tmpdir );
    $dist->regen;
    $dist->chdir_in;

    my $distname = $dist->name;
    $dist->change_build_pl({
        module_name         => $distname,
        PL_files            => {
            'bin/foo.PL'        => 'bin/foo',
            'lib/Bar.pm.PL'     => 'lib/Bar.pm',
        },
    });

    $dist->add_file("bin/foo.PL", <<'END');
open my $fh, ">", $ARGV[0] or die $!;
print $fh "foo\n";
END

    $dist->add_file("lib/Bar.pm.PL", <<'END');
open my $fh, ">", $ARGV[0] or die $!;
print $fh "bar\n";
END

    $dist->regen;
}


# Test that PL files don't get installed even in bin or lib
{
    my $mb = Module::Build->new_from_context( install_base => "test_install" );
    $mb->dispatch("install");

    ok -e "test_install/bin/foo",               "Generated PL_files installed from bin";
    ok -e "test_install/lib/perl5/Bar.pm",      "  and from lib";

    ok !-e "test_install/bin/foo.PL",           "PL_files not installed from bin";
    ok !-e "test_install/lib/perl5/Bar.pm.PL",  "  nor from lib";

    is slurp("test_install/bin/foo"), "foo\n",          "Generated bin contains correct content";
    is slurp("test_install/lib/perl5/Bar.pm"), "bar\n", "  so does the lib";
}
