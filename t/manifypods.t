#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use File::Spec ();
my $common_pl = File::Spec->catfile( 't', 'common.pl' );
require $common_pl;


#########################

use Test::More;
use Module::Build;

if ( Module::Build->current->feature('manpage_support') ) {
  plan tests => 21;
} else {
  plan skip_all => 'manpage_support feature is not enabled';
}

#########################


use Cwd ();
my $cwd = Cwd::cwd;
my $tmp = File::Spec->catdir( $cwd, 't', '_tmp' );

use DistGen;
my $dist = DistGen->new( dir => $tmp );
$dist->add_file( 'bin/nopod.pl', <<'---' );
#!perl -w
print "sample script without pod to test manifypods action\n";
---
$dist->add_file( 'bin/haspod.pl', <<'---' );
#!perl -w
print "Hello, world";

__END__

=head1 NAME

haspod.pl - sample script with pod to test manifypods action

=cut
---
$dist->add_file( 'lib/Simple/NoPod.pm', <<'---' );
package Simple::NoPod;
1;
---
$dist->add_file( 'lib/Simple/AllPod.pod', <<'---' );
=head1 NAME

Simple::AllPod - Pure POD

=head1 AUTHOR

Simple Man <simple@example.com>

=cut
---
$dist->regen;


chdir( $dist->dirname ) or die "Can't chdir to '@{[$dist->dirname]}': $!";


my $destdir = File::Spec->catdir($cwd, 't', 'install_test');


my $m = Module::Build->new(
  install_base => $destdir,
  module_name  => $dist->name,
  scripts      => [ File::Spec->catfile( 'bin', 'nopod.pl'  ),
                    File::Spec->catfile( 'bin', 'haspod.pl' )  ],
);

$m->add_to_cleanup($destdir);


is( ref $m->{properties}->{bindoc_dirs}, 'ARRAY', 'bindoc_dirs' );
is( ref $m->{properties}->{libdoc_dirs}, 'ARRAY', 'libdoc_dirs' );

my %man = (
	   sep  => $m->manpage_separator,
	   dir1 => 'man1',
	   dir3 => 'man3',
	   ext1 => $m->{config}{man1ext},
	   ext3 => $m->{config}{man3ext},
	  );

my %distro = (
	      'bin/nopod.pl'          => '',
              'bin/haspod.pl'         => "haspod.pl.$man{ext1}",
	      'lib/Simple.pm'         => "Simple.$man{ext3}",
              'lib/Simple/NoPod.pm'   => '',
              'lib/Simple/AllPod.pod' => "Simple$man{sep}AllPod.$man{ext3}",
	     );

%distro = map {$m->localize_file_path($_), $distro{$_}} keys %distro;

$m->dispatch('build');

eval {$m->dispatch('docs')};
ok ! $@;

while (my ($from, $v) = each %distro) {
  if (!$v) {
    ok ! $m->contains_pod($from), "$from should not contain POD";
    next;
  }
  
  my $to = File::Spec->catfile('blib', ($from =~ /^lib/ ? 'libdoc' : 'bindoc'), $v);
  ok $m->contains_pod($from), "$from should contain POD";
  ok -e $to, "Created $to manpage";
}


$m->dispatch('install');

while (my ($from, $v) = each %distro) {
  next unless $v;
  my $to = File::Spec->catfile($destdir, 'man', $man{($from =~ /^lib/ ? 'dir3' : 'dir1')}, $v);
  ok -e $to, "Created $to manpage";
}

$m->dispatch('realclean');


# revert to a pristine state
chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
$dist->remove;
$dist = DistGen->new( dir => $tmp );
$dist->regen;
chdir( $dist->dirname ) or die "Can't chdir to '@{[$dist->dirname]}': $!";


my $m2 = Module::Build->new(
  module_name => $dist->name,
  libdoc_dirs => [qw( foo bar baz )],
);

is( $m2->{properties}->{libdoc_dirs}->[0], 'foo', 'override libdoc_dirs' );

# Make sure we can find our own action documentation
ok  $m2->get_action_docs('build');
ok !$m2->get_action_docs('foo');

# Make sure those docs are the correct ones
foreach ('ppd', 'disttest') {
  my $docs = $m2->get_action_docs($_);
  like $docs, qr/=item $_/;
  unlike $docs, qr/\n=/, $docs;
}


# cleanup
chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
$dist->remove;

use File::Path;
rmtree( $tmp );
