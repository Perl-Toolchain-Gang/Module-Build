#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use Test::More tests => 50;


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


############################################################

# File with corresponding package (w/ or w/o version)
# Module/Foo.pm => Module::Foo v1.23

my $provides = $mb->find_dist_packages;
is( $provides->{Simple}{version}, '0.01' );

# File with no corresponding package (w/ or w/o version)
# Module/Foo.pm => Module::Baz v1.23 (No Module::Foo)

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Foo::Bar;
$VERSION = '1.23';
1;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( ! exists( $provides->{Simple} ) );
is( $provides->{'Foo::Bar'}{version}, '1.23' );
is( keys( %$provides ), 1 );

# Single file with multiple differing packages (w/ or w/o version)
# Module/Foo.pm => Module::Foo
# Module/Foo.pm => Module::Bar

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
1;
package Foo::Bar;
$VERSION = '1.23';
1;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
is( $provides->{Simple}{version}, '1.23' );
is( $provides->{'Foo::Bar'}{version}, '1.23' );
is( keys( %$provides ), 2 );


# Single file with multiple differing packages, no corresponding package
# Module/Foo.pm => Module::Baz
# Module/Foo.pm => Module::Bar

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Foo;
$VERSION = '1.23';
1;
package Foo::Bar;
$VERSION = '1.23';
1;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( ! exists( $provides->{Simple} ) );
is( $provides->{'Foo'}{version}, '1.23' );
is( $provides->{'Foo::Bar'}{version}, '1.23' );
is( keys( %$provides ), 2 );


# Single file with same package appearing multiple times, no version
# Module/Foo.pm => Module::Foo
# Module/Foo.pm => Module::Foo

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
1;
package Simple;
1;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{'Simple'} ) );
ok( ! exists( $provides->{'Simple'}{version} ) );
is( keys( %$provides ), 1 );

# Single file with same package appearing multiple times, single version
# Module/Foo.pm => Module::Foo v1.23
# Module/Foo.pm => Module::Foo

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
1;
package Simple;
1;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{'Simple'}{version} ) );
is( $provides->{'Simple'}{version}, '1.23' );
is( keys( %$provides ), 1 );


# Single file with same package appearing multiple times, single version
# Module/Foo.pm => Module::Foo
# Module/Foo.pm => Module::Foo v1.23

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
1;
package Simple;
$VERSION = '1.23';
1;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{'Simple'}{version} ) );
is( $provides->{'Simple'}{version}, '1.23' );
is( keys( %$provides ), 1 );


# Single file with same package appearing multiple times, conflicting versions
# Module/Foo.pm => Module::Foo v1.23
# Module/Foo.pm => Module::Foo v2.34

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
1;
package Simple;
$VERSION = '2.34';
1;
---
$dist->regen( clean => 1 );
my $err = '';
$err = stderr_of( sub { $mb = Module::Build->new_from_context } );
$err = stderr_of( sub { $provides = $mb->find_dist_packages } );
ok( exists( $provides->{'Simple'}{version} ) );
is( $provides->{'Simple'}{version}, '1.23' );
like( $err, qr/already declared/ );
is( keys( %$provides ), 1 );

# (Same as above three cases except with no corresponding package)
# Module/Foo.pm => Module::Baz
# Module/Foo.pm => Module::Baz

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Foo;
$VERSION = '1.23';
1;
package Foo;
$VERSION = '2.34';
1;
---
$dist->regen( clean => 1 );
$err = stderr_of( sub { $mb = Module::Build->new_from_context } );
$err = stderr_of( sub { $provides = $mb->find_dist_packages } );
ok( exists( $provides->{'Foo'}{version} ) );
is( $provides->{'Foo'}{version}, '1.23' );
like( $err, qr/already declared/ );
is( keys( %$provides ), 1 );


# Multiple files with same package, no version
# Module/Foo.pm => Module::Foo
# Module/Bar.pm => Module::Foo

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
1;
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Simple;
1;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{'Simple'} ) );
ok( ! exists( $provides->{'Simple'}{version} ) );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );

# Multiple files with same package, single version in corresponding package
# Module/Foo.pm => Module::Foo v1.23
# Module/Bar.pm => Module::Foo

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
1;
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Simple;
1;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{'Simple'}{version} ) );
is( $provides->{'Simple'}{version}, '1.23' );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );

# Multiple files with same package,
#   single version in non-corresponding package
# Module/Foo.pm => Module::Foo
# Module/Bar.pm => Module::Foo v1.23

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
1;
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Simple;
$VERSION = '1.23';
1;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$err = stderr_of( sub { $provides = $mb->find_dist_packages } );
ok( ! exists( $provides->{'Simple'}{version} ) );
ok( ! defined( $provides->{'Simple'}{version} ) );
like( $err, qr/conflicts/ );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );


# Multiple files with same package, conflicting versions
# Module/Foo.pm => Module::Foo v1.23
# Module/Bar.pm => Module::Foo v2.34

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
1;
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Simple;
$VERSION = '2.34';
1;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$err = stderr_of( sub { $provides = $mb->find_dist_packages } );
ok( exists( $provides->{'Simple'}{version} ) );
is( $provides->{'Simple'}{version}, '1.23' );
like( $err, qr/conflicts/ );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );


# Multiple files with same package, multiple agreeing versions
# Module/Foo.pm => Module::Foo v1.23
# Module/Bar.pm => Module::Foo v1.23

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
1;
---
$dist->add_file( 'lib/Simple2.pm', <<'---' );
package Simple;
$VERSION = '1.23';
1;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$err = stderr_of( sub { $provides = $mb->find_dist_packages } );
ok( exists( $provides->{'Simple'}{version} ) );
is( $provides->{'Simple'}{version}, '1.23' );
is( $err, '' );
is( keys( %$provides ), 1 );

$dist->remove_file( 'lib/Simple2.pm' );


# (Same as above five cases except with non-corresponding package)
# Module/Foo.pm => Module::Baz
# Module/Bar.pm => Module::Baz

# What about private packages?
# Module/Foo.pm => Module::_Private

$dist->change_file( 'lib/Simple.pm', <<'---' );
package Simple;
$VERSION = '1.23';
1;
package Simple::_private;
$VERSION = '2.34';
1;
---
$dist->regen( clean => 1 );
$mb = Module::Build->new_from_context;
$provides = $mb->find_dist_packages;
ok( exists( $provides->{Simple} ) );
is( $provides->{'Simple'}{version}, '1.23' );
ok( ! exists( $provides->{'Simple::_private'} ) );
is( keys( %$provides ), 1 );


# Files with no packages?
# Module/Foo.pm => =pod..=cut (no package declaration)




# cleanup
chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
$dist->remove;

use File::Path;
rmtree( $tmp );
