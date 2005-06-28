#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use File::Spec ();
my $common_pl = File::Spec->catfile( 't', 'common.pl' );
require $common_pl;

use Cwd ();
my $cwd = Cwd::cwd;

#########################

use Test::More;

use Module::Build;
if ( Module::Build->current->feature('manpage_support') ) {
  plan tests => 21;
} else {
  plan skip_all => 'manpage_support feature is not enabled';
}

#########################

use File::Path qw( rmtree );

my $install = File::Spec->catdir( $cwd, 't', '_tmp' );
chdir File::Spec->catdir( 't','Sample' ) or die "Can't chdir to t/Sample: $!";

my $m = new Module::Build
  (
   install_base => $install,
   module_name  => 'Sample',
   scripts      => [ 'script', File::Spec->catfile( 'bin', 'sample.pl' ) ],
  );

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
	      'bin/sample.pl' => "sample.pl.$man{ext1}",
	      'lib/Sample/Docs.pod' => "Sample$man{sep}Docs.$man{ext3}",
	      'lib/Sample.pm' => "Sample.$man{ext3}",
	      'script' => '',
	      'lib/Sample/NoPod.pm' => '',
	     );
# foreach(keys %foo) doesn't give proper lvalues on 5.005, so we use the ugly way
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


$m->add_to_cleanup($install);
$m->dispatch('install');

while (my ($from, $v) = each %distro) {
  next unless $v;
  my $to = File::Spec->catfile($install, 'man', $man{($from =~ /^lib/ ? 'dir3' : 'dir1')}, $v);
  ok -e $to, "Created $to manpage";
}

$m->dispatch('realclean');


my $m2 = new Module::Build
  (
   module_name     => 'Sample',
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
