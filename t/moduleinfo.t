
use strict;
use Test;

BEGIN {
  plan tests => 27;

  chdir( 't' ) if -d 't';

  push( @INC, 'lib' );
  require DistGen;
  require File::Spec;
}

use Module::Build::ModuleInfo;
ok(1);


# class method C<find_module_by_name>
my $module = Module::Build::ModuleInfo->find_module_by_name(
               'Module::Build::ModuleInfo' );
ok( -e $module );


# fail on invalid module name
my $pm_info = Module::Build::ModuleInfo->new_from_module( 'Foo::Bar' );
ok( !defined( $pm_info ) );


# fail on invalid filename
my $file = File::Spec->catfile( 'Foo', 'Bar.pm' );
$pm_info = Module::Build::ModuleInfo->new_from_file( $file );
ok( !defined( $pm_info ) );


my $dist = DistGen->new();
$dist->regen();

# construct from module filename
$file = File::Spec->catfile( $dist->dirname, 'lib', 'Simple.pm' );
$pm_info =
    Module::Build::ModuleInfo->new_from_file( $file );
ok( defined( $pm_info ) );

# construct from module name, using custom include path
my $inc = File::Spec->catdir( qw( Simple lib ) );
$pm_info = Module::Build::ModuleInfo->new_from_module(
	     'Simple', inc => [ $inc, @INC ] );
ok( defined( $pm_info ) );


# parse various module $VERSION lines
my @modules = (
  <<'---', # declared & defined on same line with 'our'
package Simple;
our $VERSION = '1.23';
1;
---
  <<'---', # declared & defined on seperate lines with 'our'
package Simple;
our $VERSION;
$VERSION = '1.23';
1;
---
  <<'---', # use vars
package Simple;
use vars qw( $VERSION );
$VERSION = '1.23';
1;
---
  <<'---', # choose the right default package based on package/file name
package Simple::_private;
our $VERSION = '0';
1;
package Simple;
our $VERSION = '1.23'; # this should be chosen for version
1;
---
  <<'---', # just read the first $VERSION line
package Simple;
our $VERSION = '1.23'; # we should see this line
$VERSION = eval $VERSION; # and ignore this one
1;
---
);

$dist = DistGen->new();
foreach my $module ( @modules ) {
  $dist->change_file( 'lib/Simple.pm', $module );
  $dist->regen( clean => 1 );
  $file = File::Spec->catfile( $dist->dirname, 'lib', 'Simple.pm' );
  my $pm_info = Module::Build::ModuleInfo->new_from_file( $file );
  ok( $pm_info->version eq '1.23' );
}
$dist->remove();


# parse $VERSION lines scripts for package main
my @scripts = (
  <<'---', # package main declared
#!perl -w
package main;
our $VERSION = '0.01';
---
  <<'---', # on first non-comment line, non declared package main
#!perl -w
our $VERSION = '0.01';
---
  <<'---', # after non-comment line
#!perl -w
use strict;
our $VERSION = '0.01';
---
  <<'---', # 1st declared package
#!perl -w
package main;
our $VERSION = '0.01';
package _private;
our $VERSION = '999';
1;
---
  <<'---', # 2nd declared package
#!perl -w
package _private;
our $VERSION = '999';
1;
package main;
our $VERSION = '0.01';
---
  <<'---', # split package
#!perl -w
package main;
1;
package _private;
our $VERSION = '999';
1;
package main;
our $VERSION = '0.01';
1;
---
);

$dist = DistGen->new();
foreach my $script ( @scripts ) {
  $dist->change_file( 'bin/simple.plx', $script );
  $dist->regen();
  $pm_info =
    Module::Build::ModuleInfo->new_from_file( 'Simple/bin/simple.plx' );
  ok( defined( $pm_info ) && $pm_info->version eq '0.01' );
}


# examine properties of a module: name, pod, etc
$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
our $VERSION = '0.01';
1;
package Simple::Ex;
our $VERSION = '0.02';
1;
=head1 NAME

Simple - It's easy.

=head1 AUTHOR

Simple Simon

=cut
---
$dist->regen();

$pm_info = Module::Build::ModuleInfo->new_from_module(
             'Simple', inc => [ $inc, @INC ] );

ok( $pm_info->name() eq 'Simple' );

ok( $pm_info->version() eq '0.01' );

# got correct version for secondary package
ok( $pm_info->version( 'Simple::Ex' ) eq '0.02' );

my $filename = $pm_info->filename();
ok( defined( $filename ) && length( $filename ) );

my @packages = $pm_info->packages_inside();
ok( scalar( @packages ) == 2 );
ok( $packages[0] eq 'Simple' );

# we can detect presence of pod regardless of whether we are collecting it
ok( $pm_info->contains_pod() );

my @pod = $pm_info->pod_inside();
ok( "@pod" eq 'NAME AUTHOR' );

# no pod is collected
my $name = $pm_info->pod('NAME');
ok( !defined( $name ) );


# collect_pod
$pm_info = Module::Build::ModuleInfo->new_from_module(
             'Simple', inc => [ $inc, @INC ], collect_pod => 1 );

$name = $pm_info->pod('NAME');
if ( $name ) {
  $name =~ s/^\s+//;
  $name =~ s/\s+$//;
}
ok( $name eq q|Simple - It's easy.| );



$dist->remove();
