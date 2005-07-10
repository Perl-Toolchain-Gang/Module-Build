#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use Test::More tests => 102;


use File::Spec ();
my $common_pl = File::Spec->catfile( 't', 'common.pl' );
require $common_pl;


use Cwd ();
my $cwd = Cwd::cwd;
my $tmp = File::Spec->catdir( $cwd, 't', '_tmp' );

use DistGen;
my $dist = DistGen->new( dir => $tmp );
$dist->change_file( 'Build.PL', <<"---" );
use Module::Build;
my \$builder = Module::Build->new(
    module_name         => '@{[$dist->name]}',
    dist_version        => '3.14159265',
    license             => 'perl',
);

\$builder->create_build_script();
---
$dist->regen;

chdir( $dist->dirname ) or die "Can't chdir to '@{[$dist->dirname]}': $!";

use Module::Build;
my $mb = Module::Build->new_from_context;


############################## Single Module

# File with corresponding package (w/ or w/o version)
# Simple.pm => Simple v1.23

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
my $provides = $mb->find_dist_packages;
ok( exists( $provides->{Simple} ), 'single package' );
is( $provides->{Simple}{file}, 'lib/Simple.pm', '  in corresponding file' );
is( $provides->{Simple}{version}, '1.23', '  with version' );
is( keys( %$provides ), 1 );

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{Simple} ), 'single package' );
is( $provides->{Simple}{file}, 'lib/Simple.pm', '  in corresponding file' );
is( $provides->{Simple}{version}, undef, '  without version' );
is( keys( %$provides ), 1 );

# File with no corresponding package (w/ or w/o version)
# Simple.pm => Foo::Bar v1.23

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Foo::Bar;
$VERSION = '1.23';
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{'Foo::Bar'} ), 'single package' );
is( $provides->{'Foo::Bar'}{file}, 'lib/Simple.pm',
    '  in non-corresponding file' );
is( $provides->{'Foo::Bar'}{version}, '1.23', '  with version' );
ok( ! exists( $provides->{Simple} ), '  no corresponding package for file' );
is( keys( %$provides ), 1 );

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Foo::Bar;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{'Foo::Bar'} ), 'single package' );
is( $provides->{'Foo::Bar'}{file}, 'lib/Simple.pm',
    '  in non-corresponding file' );
is( $provides->{'Foo::Bar'}{version}, undef, '  without version' );
ok( ! exists( $provides->{Simple} ), '  no corresponding package for file' );
is( keys( %$provides ), 1 );


# Single file with multiple differing packages (w/ or w/o version)
# Simple.pm => Simple
# Simple.pm => Foo::Bar

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
package Foo::Bar;
$VERSION = '1.23';
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
is( $provides->{Simple}{version}, '1.23', 'multiple packages with versions' );
is( $provides->{'Foo::Bar'}{version}, '1.23' );
is( $provides->{Simple}{file}, 'lib/Simple.pm',
    '  with file corresponding to one package' );
is( $provides->{'Foo::Bar'}{file}, 'lib/Simple.pm' );
is( keys( %$provides ), 2 );


# Single file with multiple differing packages, no corresponding package
# Simple.pm => Foo
# Simple.pm => Foo::Bar

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Foo;
$VERSION = '1.23';
package Foo::Bar;
$VERSION = '1.23';
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
is( $provides->{Foo}{version}, '1.23', 'multiple packages with versions' );
is( $provides->{'Foo::Bar'}{version}, '1.23' );
ok( ! exists( $provides->{Simple} ),
    '  without package corresponding to file' );
is( keys( %$provides ), 2 );


# Single file with same package appearing multiple times, no version
#   only record a single instance
# Simple.pm => Simple
# Simple.pm => Simple

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
package Simple;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{Simple} ),
    'single file with corresponding package multiple times' );
ok( ! exists( $provides->{Simple}{version} ), '  without version' );
is( keys( %$provides ), 1, '  records only one occurrence' );


# Single file with same package appearing multiple times, single
# version 1st package:
# Simple.pm => Simple v1.23
# Simple.pm => Simple

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
package Simple;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{Simple} ),
    'single file with corresponding package multiple times' );
is( $provides->{Simple}{version}, '1.23',
    '  with version only in first occurrence' );
is( keys( %$provides ), 1 );


# Single file with same package appearing multiple times, single
# version 2nd package
# Simple.pm => Simple
# Simple.pm => Simple v1.23

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
package Simple;
$VERSION = '1.23';
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{Simple} ),
    'single file with corresponding package multiple times' );
is( $provides->{Simple}{version}, '1.23',
    '  with version only in second occurrence' );
is( keys( %$provides ), 1 );


# Single file with same package appearing multiple times, conflicting versions
# Simple.pm => Simple v1.23
# Simple.pm => Simple v2.34

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
package Simple;
$VERSION = '2.34';
---
$dist->regen( clean => 1 );
my $err = '';
$err = stderr_of( sub { $mb = Module::Build->new_from_context } );
$err = stderr_of( sub { $provides = $mb->find_dist_packages } );
ok( exists( $provides->{Simple} ),
    'single file with corresponding package multiple times' );
like( $err, qr/already declared/, '  with conflicting versions reported' );
is( $provides->{Simple}{version}, '1.23', '  only first version is recorded' );
is( keys( %$provides ), 1 );


# (Same as above three cases except with no corresponding package)
# Simple.pm => Foo v1.23
# Simple.pm => Foo v2.34

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Foo;
$VERSION = '1.23';
package Foo;
$VERSION = '2.34';
---
$dist->regen( clean => 1 );
$err = stderr_of( sub { $mb = Module::Build->new_from_context } );
$err = stderr_of( sub { $provides = $mb->find_dist_packages } );
ok( ! exists( $provides->{Simple} ),
    'single file with non-corresponding package multiple times' );
like( $err, qr/already declared/, '  with conflicting versions reported' );
is( $provides->{Foo}{version}, '1.23', '  only first version is recorded' );
is( keys( %$provides ), 1 );



############################## Multiple Modules

# Multiple files with same package, no version
# Simple.pm  => Simple
# Simple2.pm => Simple

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Simple;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{Simple} ), 'multiple files with same package' );
ok( ! exists( $provides->{Simple}{version} ), '  without any versions' );
is( $provides->{Simple}{file}, 'lib/Simple.pm',
    '  only recording occurrence in corresponding file' );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );


# Multiple files with same package, single version in corresponding package
# Simple.pm  => Simple v1.23
# Simple2.pm => Simple

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Simple;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{Simple} ), 'multiple files with same package' );
is( $provides->{Simple}{version}, '1.23',
    '  with version in corresponding file' );
is( $provides->{Simple}{file}, 'lib/Simple.pm',
    '  only recording occurrence with version' );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );


# Multiple files with same package,
#   single version in non-corresponding package
# Simple.pm  => Simple
# Simple2.pm => Simple v1.23

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Simple;
$VERSION = '1.23';
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{Simple} ), 'multiple files with same package' );
is( $provides->{Simple}{version}, '1.23',
    '  with version in non-corresponding file' );
is( $provides->{Simple}{file}, 'lib/Simple2.pm',
    '  only recording occurrence with version' );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );


# Multiple files with same package, conflicting versions
# Simple.pm  => Simple v1.23
# Simple2.pm => Simple v2.34

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Simple;
$VERSION = '2.34';
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$err = stderr_of( sub { $provides = $mb->find_dist_packages } );
ok( exists( $provides->{Simple} ), 'multiple files with same package' );
like( $err, qr/Found conflicting versions for package/,
      '  with conflicting versions reported' );
is( $provides->{Simple}{version}, '1.23',
    '  only recording occurrence with package in corresponding file' );
is( $provides->{Simple}{file}, 'lib/Simple.pm' );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );


# Multiple files with same package, multiple agreeing versions
# Simple.pm  => Simple v1.23
# Simple2.pm => Simple v1.23

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Simple;
$VERSION = '1.23';
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$err = stderr_of( sub { $provides = $mb->find_dist_packages } );
ok( exists( $provides->{Simple} ), 'multiple files with same package' );
is( $provides->{Simple}{version}, '1.23', '  with same version' );
is( $provides->{Simple}{file}, 'lib/Simple.pm',
    '  only recording occurrence with package in corresponding file' );
is( $err, '', '  no conflicts reported' );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );


############################################################
#
# (Same as above five cases except with non-corresponding package)
#

# Multiple files with same package, no version
# Simple.pm  => Foo
# Simple2.pm => Foo

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Foo;
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Foo;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{Foo} ), 'multiple files with same package' );
ok( ! exists( $provides->{Foo}{version} ), '  without any versions' );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );


# Multiple files with same package, version in first file
# Simple.pm  => Foo v1.23
# Simple2.pm => Foo

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Foo;
$VERSION = '1.23';
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Foo;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{Foo} ), 'multiple files with same package' );
is( $provides->{Foo}{version}, '1.23' );
is( $provides->{Foo}{file}, 'lib/Simple.pm',
    '  only recording occurrence with version' );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );


# Multiple files with same package, version in second file
# Simple.pm  => Foo
# Simple2.pm => Foo v1.23

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Foo;
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Foo;
$VERSION = '1.23';
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{Foo} ), 'multiple files with same package' );
is( $provides->{Foo}{version}, '1.23' );
is( $provides->{Foo}{file}, 'lib/Simple2.pm',
    '  only recording occurrence with version' );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );


# Multiple files with same package, conflicting versions
# Simple.pm  => Foo v1.23
# Simple2.pm => Foo v2.34

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Foo;
$VERSION = '1.23';
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Foo;
$VERSION = '2.34';
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$err = stderr_of( sub { $provides = $mb->find_dist_packages } );
ok( exists( $provides->{Foo} ), 'multiple files with same package' );
like( $err, qr/Found conflicting versions for package/,
      '  with conflicting versions reported' );
ok( exists( $provides->{Foo}{version} ), '  recording any version' );
ok( exists( $provides->{Foo}{file} ), '  recording any file' );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );


# Multiple files with same package, multiple agreeing versions
# Simple.pm  => Foo v1.23
# Simple2.pm => Foo v1.23

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Foo;
$VERSION = '1.23';
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Foo;
$VERSION = '1.23';
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$err = stderr_of( sub { $provides = $mb->find_dist_packages } );
ok( exists( $provides->{Foo} ), 'multiple files with same package' );
is( $provides->{Foo}{version}, '1.23', '  with same version' );
is( $err, '', '  no conflicts reported' );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );

############################################################
# Conflicts amoung primary & multiple alternatives

# multiple files, conflicting version in corresponding file
$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Simple;
$VERSION = '2.34';
---
$dist->add_file( 'lib/Simple3.pm', <<'---' );
package Simple;
$VERSION = '2.34';
---
$dist->regen( clean => 1 );
$err = stderr_of( sub { $mb = Module::Build->new_from_context } );
$err = stderr_of( sub { $provides = $mb->find_dist_packages } );
ok( exists( $provides->{Simple} ), 'multiple files with same package' );
like( $err, qr/Found conflicting versions for package/,
      '  corresponding package conflicts with multiple alternatives' );
is( $provides->{Simple}{version}, '1.23' );
is( $provides->{Simple}{file}, 'lib/Simple.pm',
    '  recording occurrence in corresponding file' );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );
$dist->remove_file( 'lib/Simple3.pm' );

# multiple files, conflicting version in non-corresponding file
$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Simple;
$VERSION = '1.23';
---
$dist->add_file( 'lib/Simple3.pm', <<'---' );
package Simple;
$VERSION = '2.34';
---
$dist->regen( clean => 1 );
$err = stderr_of( sub { $mb = Module::Build->new_from_context } );
$err = stderr_of( sub { $provides = $mb->find_dist_packages } );
ok( exists( $provides->{Simple} ), 'multiple files with same package' );
like( $err, qr/Found conflicting versions for package/,
      '  only one alternative conflicts with corresponding package' );
is( $provides->{Simple}{version}, '1.23' );
is( $provides->{Simple}{file}, 'lib/Simple.pm',
    '  recording occurrence in corresponding file' );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );
$dist->remove_file( 'lib/Simple3.pm' );


############################################################
# Don't record private packages (beginning with underscore)
# Simple.pm => Simple::_private
# Simple.pm => Simple::_private::too

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
package Simple::_private;
$VERSION = '2.34';
package Simple::_private::too;
$VERSION = '3.45';
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{Simple} ),
    'single file with single non-private package' );
ok( ! exists( $provides->{'Simple::_private'} ),
    "  no private package 'Simple::_private'" );
ok( ! exists( $provides->{'Simple::_private::too'} ),
    "  no private sub-package 'Simple::_private::too'" );
is( keys( %$provides ), 1 );


############################################################
# Files with no packages?

# Simple.pm => <empty>

$dist->change_file( 'lib/Simple.pm', '' );
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
is( keys( %$provides ), 0 );

# Simple.pm => =pod..=cut (no package declaration)
$dist->change_file( 'lib/Simple.pm', <<'---' );
=pod

=head1 NAME

Simple - Pure Documentation

=head1 DESCRIPTION

Doesn't do anything.

=cut
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
is( keys( %$provides ), 0 );


############################################################
# cleanup
chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
$dist->remove;

use File::Path;
rmtree( $tmp );
