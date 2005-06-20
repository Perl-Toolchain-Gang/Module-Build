#!/usr/bin/perl -w

use strict;

use Config;
use File::Spec::Functions qw( catdir );

use File::Spec;

BEGIN {
  my $common_pl = File::Spec->catfile('t', 'common.pl');
  require $common_pl;
}


use Test::More tests => 32;

use_ok 'Module::Build';


my $m = Module::Build->current;
isa_ok( $m, 'Module::Build::Base' );

$m->installdirs('site');

# Check that we install into the proper default locations.

$m->install_base(undef);
$m->prefix(undef);

is( $m->install_base, undef );
is( $m->prefix,       undef );

test_install_destinations( $m, {
        lib     => $Config{installsitelib},
        arch    => $Config{installsitearch},
        bin     => $Config{installsitebin} || $Config{installbin},
        script  => $Config{installsitescript} || $Config{installsitebin} ||
                   $Config{installscript},
        bindoc  => $Config{installsiteman1dir} || $Config{installman1dir},
        libdoc  => $Config{installsiteman3dir} || $Config{installman3dir}
});
        

my $install_base = catdir( 'foo', 'bar' );
$m->install_base( $install_base );

is( $m->prefix,       undef );
is( $m->install_base, $install_base );


test_install_destinations( $m, {
        lib     => catdir( $install_base, 'lib', 'perl5' ),
        arch    => catdir( $install_base, 'lib', 'perl5', $Config{archname} ),
        bin     => catdir( $install_base, 'bin' ),
        script  => catdir( $install_base, 'bin' ),
        bindoc  => catdir( $install_base, 'man', 'man1'),
        libdoc  => catdir( $install_base, 'man', 'man3' ),
});


$m->install_base( undef );
ok( !defined $m->install_base );


my $prefix = catdir( qw( some prefix ) );
$m->prefix( $prefix );
is( $m->{properties}{prefix}, $prefix );

test_prefix($prefix);


# Check that we can return to normality after setting prefix.
$m->install_base( $install_base );

test_install_destinations( $m, {
        lib     => catdir( $install_base, 'lib', 'perl5' ),
        arch    => catdir( $install_base, 'lib', 'perl5', $Config{archname} ),
        bin     => catdir( $install_base, 'bin' ),
        script  => catdir( $install_base, 'bin' ),
        bindoc  => catdir( $install_base, 'man', 'man1'),
        libdoc  => catdir( $install_base, 'man', 'man3' ),
});


sub test_prefix {
    my ($prefix) = shift;
  
    foreach my $type (qw(lib arch bin script bindoc libdoc)) {
        my $dest = $m->install_destination( $type );
        like( $dest, "/^\Q$prefix\E/");
    }
}


sub test_install_destinations {
    my($mb, $expect) = @_;

    while( my($type, $expect) = each %$expect ) {
        is( $m->install_destination($type), $expect, $type );
    }
}
