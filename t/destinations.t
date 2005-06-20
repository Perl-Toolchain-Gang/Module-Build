#!/usr/bin/perl -w

use strict;

use Config;
use File::Spec::Functions qw( catdir );

use File::Spec;

BEGIN {
  my $common_pl = File::Spec->catfile('t', 'common.pl');
  require $common_pl;
}


use Test::More tests => 31;

use_ok 'Module::Build';


my $m = Module::Build->current;
isa_ok( $m, 'Module::Build::Base' );

ok( !defined $m->install_base );
ok( !defined $m->prefix );

# Do default tests here

is( $m->install_destination( 'lib' ), $Config{ installsitelib } );
is( $m->install_destination( 'arch' ), $Config{ installsitearch } );
is( $m->install_destination( 'bin' ), $Config{ installsitebin } || $Config{ installbin } );
is( $m->install_destination( 'script' ), $Config{ installsitescript } || $Config{ installsitebin } || $Config{ installscript } );
is( $m->install_destination( 'bindoc' ), $Config{ installsiteman1dir } || $Config{ installman1dir } );
is( $m->install_destination( 'libdoc' ), $Config{ installsiteman3dir } || $Config{ installman3dir } );

my $install_base = catdir( 'foo', 'bar' );

$m->install_base( $install_base );
ok( !defined $m->prefix );

is( $m->install_destination( 'lib' ),    catdir( $install_base, 'lib', 'perl5' ) );
is( $m->install_destination( 'arch' ),   catdir( $install_base, 'lib', 'perl5', $Config{archname} ) );
is( $m->install_destination( 'bin' ),    catdir( $install_base, 'bin' ) );
is( $m->install_destination( 'script' ), catdir( $install_base, 'bin' ) );
is( $m->install_destination( 'bindoc' ), catdir( $install_base, 'man', 'man1') );
is( $m->install_destination( 'libdoc' ), catdir( $install_base, 'man', 'man3' ) );

$m->install_base( undef );
ok( !defined $m->install_base );

##### Adaptation START
# Adapted from ExtUtils::MakeMaker::MM_Any::init_INSTALL_from_PREFIX()

my $core_prefix = $Config{installprefixexp} || $Config{installprefix} || 
                  $Config{prefixexp}        || $Config{prefix} || '';
my $vend_prefix = $Config{usevendorprefix}  ? $Config{vendorprefixexp} : '';
my $site_prefix = $Config{siteprefixexp}    || $core_prefix;

my $libstyle = $Config{installstyle} || 'lib/perl5';
my $manstyle = $libstyle eq 'lib/perl5' ? $libstyle : '';

##### Adaptation END

my $prefix = catdir( qw( some prefix ) );
$m->prefix( $prefix );
is( $m->{properties}{prefix}, $prefix );

my $c = \%Config;

test_prefix('lib');
test_prefix('arch');
test_prefix('bin');
test_prefix('script');
test_prefix('bindoc');
test_prefix('libdoc');


$m->install_base( $install_base );

is( $m->install_destination( 'lib' ),    catdir( $install_base, 'lib', 'perl5' ) );
is( $m->install_destination( 'arch' ),   catdir( $install_base, 'lib', 'perl5', $Config{archname} ) );
is( $m->install_destination( 'bin' ),    catdir( $install_base, 'bin' ) );
is( $m->install_destination( 'script' ), catdir( $install_base, 'bin' ) );
is( $m->install_destination( 'bindoc' ), catdir( $install_base, 'man', 'man1') );
is( $m->install_destination( 'libdoc' ), catdir( $install_base, 'man', 'man3' ) );

sub test_prefix {
  my ($type) = @_;
  
  my $dest = $m->install_destination( $type );
  unless ($dest) {
    skip_subtest("No target install location for type '$type'");
    return;
  }
  
  like( $dest, "/^\Q$prefix\E/");
}

