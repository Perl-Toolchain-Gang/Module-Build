use strict;
use warnings;
use Test::More;
use File::Find qw/find/;
use File::Spec;

my @files;
find( sub { -f && /\.pm$/ && push @files, $File::Find::name }, 'lib' );

plan tests => scalar @files;

for my $f ( sort @files ) {
  my $mod = join("::",File::Spec->splitdir(File::Spec->abs2rel($f, 'lib')));
  $mod =~ s{\.pm$}{};
  require_ok( $mod );
}

