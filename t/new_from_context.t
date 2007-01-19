#!/usr/bin/perl

use warnings;
use strict;
use lib $ENV{PERL_CORE} ? '../lib/Module/Build/t/lib' : 't/lib';
use MBTest tests => 4;

use Cwd ();
my $cwd = Cwd::cwd;
my $tmp = File::Spec->catdir( $cwd, 't', '_tmp' );

use DistGen;
my $dist = DistGen->new( dir => $tmp );
$dist->regen;

chdir( $dist->dirname ) or die "Can't chdir to '@{[$dist->dirname]}': $!";

use IO::File;
use Module::Build;

# echo 'die' > badlib/Build.PL
my $libdir = 'badlib';
unless (-d $libdir) {
  mkdir($libdir, 0777) or die "Can't create $libdir: $!";
}
ok -d $libdir;
my $filename = 'Build.PL';
my $file = File::Spec->catfile($libdir, $filename);
my $fh = IO::File->new($file, '>') or die "Can't create $file: $!";
print $fh "die\n";
$fh->close;
ok -e $file;

unshift(@INC, $libdir);
my $mb = eval { Module::Build->new_from_context};
ok(! $@, 'dodged the bullet') or die;
ok($mb);

# cleanup
chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
$dist->remove;

use File::Path;
rmtree( $tmp );

# vim:ts=2:sw=2:et:sta
