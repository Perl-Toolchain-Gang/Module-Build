
use strict;
use Test;
BEGIN { plan tests => 18 }

use Module::Build::ModuleInfo;
ok(1);


# class method C<find_module_by_name>
my $module = Module::Build::ModuleInfo->find_module_by_name(
               'Module::Build::ModuleInfo' );
ok( -e $module );


my $pm_info;

# fail on invalid filename
$pm_info = Module::Build::ModuleInfo->new_from_file( 'Foo/Bar.pm' );
ok( !defined( $pm_info ) );

# construct from module filename
$pm_info =
    Module::Build::ModuleInfo->new_from_file( 't/Sample/lib/Sample.pm' );
ok( defined( $pm_info ) );

# construct from script filename
$pm_info =
    Module::Build::ModuleInfo->new_from_file( 't/Sample/bin/sample.pl' );
ok( defined( $pm_info ) );

# find $VERSION in non-declared package main of script
ok( $pm_info->version('main'), '0.01' );

# fail on invalid module name
$pm_info = Module::Build::ModuleInfo->new_from_module( 'Foo::Bar' );
ok( !defined( $pm_info ) );


$pm_info = Module::Build::ModuleInfo->new_from_module(
	     'Sample', inc => [ 't/Sample/lib', @INC ] );

# finds module in 'inc' path
ok( defined( $pm_info ) );

ok( $pm_info->name(), 'Sample' );

ok( $pm_info->version(), '0.01' );

# got correct version for secondary package
ok( $pm_info->version( 'Sample::Ex' ), '0.02' );

my $filename = $pm_info->filename();
ok( defined( $filename ) && length( $filename ) );

my @packages = $pm_info->packages_inside();
ok( scalar( @packages ), 2 );
ok( $packages[0], 'Sample' );

# we can detect presence of pod regardless of whether we are collecting it
ok( $pm_info->contains_pod() );

my @pod = $pm_info->pod_inside();
ok( "@pod", 'NAME AUTHOR OTHER' );

# no pod is collected
my $name = $pm_info->pod('NAME');
ok( !defined( $name ) );


# collect_pod
$pm_info = Module::Build::ModuleInfo->new_from_module(
             'Sample', inc => [ 't/Sample/lib', @INC ], collect_pod => 1 );

$name = $pm_info->pod('NAME');
if ( $name ) {
  $name =~ s/^\s+//;
  $name =~ s/\s+$//;
}
ok( $name, 'Sample - Foo foo sample foo' );
