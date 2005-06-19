use strict;

use Test;
BEGIN { plan tests => 32 }

use Module::Build;
ok(1);

use Config;
use File::Spec::Functions qw( catdir );

#use File::Spec;
#
#my $common_pl = File::Spec->catfile('t', 'common.pl');
#require $common_pl;

ok( $INC{'Module/Build.pm'}, '/blib/', "Make sure Module::Build was loaded from blib/");

my $m = Module::Build->current;
ok( UNIVERSAL::isa( $m, 'Module::Build::Base' ) );

ok( !defined $m->install_base );
ok( !defined $m->prefix );

# Do default tests here

ok( $m->install_destination( 'lib' ), $Config{ installsitelib } );
ok( $m->install_destination( 'arch' ), $Config{ installsitearch } );
ok( $m->install_destination( 'bin' ), $Config{ installsitebin } || $Config{ installbin } );
ok( $m->install_destination( 'script' ), $Config{ installsitescript } || $Config{ installsitebin } || $Config{ installscript } );
ok( $m->install_destination( 'bindoc' ), $Config{ installsiteman1dir } || $Config{ installman1dir } );
ok( $m->install_destination( 'libdoc' ), $Config{ installsiteman3dir } || $Config{ installman3dir } );

my $install_base = catdir( 'foo', 'bar' );

$m->install_base( $install_base );
ok( !defined $m->prefix );

ok( $m->install_destination( 'lib' ),    catdir( $install_base, 'lib', 'perl5' ) );
ok( $m->install_destination( 'arch' ),   catdir( $install_base, 'lib', 'perl5', $Config{archname} ) );
ok( $m->install_destination( 'bin' ),    catdir( $install_base, 'bin' ) );
ok( $m->install_destination( 'script' ), catdir( $install_base, 'bin' ) );
ok( $m->install_destination( 'bindoc' ), catdir( $install_base, 'man', 'man1') );
ok( $m->install_destination( 'libdoc' ), catdir( $install_base, 'man', 'man3' ) );

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
ok( $m->{properties}{prefix} eq $prefix );

my $c = \%Config;

my $naive_prefix = sub {
  my ($path) = @_;
  my $drive = ($path =~ s/^(\w:)// ? $1 : ''); # Win32 drive letters
  (my $bare = $path) =~ s!^\Q$site_prefix\E\b!!;
  return catdir($drive . $prefix, $bare);
};

ok( $m->install_destination( 'lib' ),
    $naive_prefix->($c->{installsitelib}) );

ok( $m->install_destination( 'arch' ),
    $naive_prefix->($c->{installsitearch}) );

ok( $m->install_destination( 'bin' ),
    $naive_prefix->($c->{installsitebin}) );

ok( $m->install_destination( 'script' ),
    $naive_prefix->($c->{installscript}) );

ok( $m->install_destination( 'bindoc' ),
    $naive_prefix->($c->{installsiteman1dir} || $c->{installman1dir}) );

ok( $m->install_destination( 'libdoc' ),
    $naive_prefix->($c->{installsiteman3dir} || $c->{installman3dir}));

$m->install_base( $install_base );

ok( $m->install_destination( 'lib' ),    catdir( $install_base, 'lib', 'perl5' ) );
ok( $m->install_destination( 'arch' ),   catdir( $install_base, 'lib', 'perl5', $Config{archname} ) );
ok( $m->install_destination( 'bin' ),    catdir( $install_base, 'bin' ) );
ok( $m->install_destination( 'script' ), catdir( $install_base, 'bin' ) );
ok( $m->install_destination( 'bindoc' ), catdir( $install_base, 'man', 'man1') );
ok( $m->install_destination( 'libdoc' ), catdir( $install_base, 'man', 'man3' ) );

