#!/usr/bin/perl -w

use strict;
use lib 't/lib';
use MBTest;
blib_load('Module::Build');
blib_load('Module::Build::ConfigData');

if ( Module::Build::ConfigData->feature('manpage_support') ) {
  plan tests => 33;
} else {
  plan skip_all => 'manpage_support feature is not enabled';
}


#########################


use Cwd ();
my $cwd = Cwd::cwd;
my $tmp = MBTest->tmpdir;

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


for ([1 => ".pod"], [2 => ".pm"], [3 => ".pl"], [4 => ""]) { # array of _arrays_
  $dist->add_file( "docs/myapp$_->[0]$_->[1]", <<"---" );
=head1 NAME

myapp$_->[0] - Pure POD

=head1 AUTHOR

Simple Man <simple\@example.com>

=cut
1;
---
}
$dist->regen;


$dist->chdir_in;

use File::Spec::Functions qw( catdir );
my $destdir = catdir($cwd, 't', 'install_test' . $$);


my $mb = Module::Build->new(
  module_name      => $dist->name,
  install_base     => $destdir,
  bindoc_dirs      => ['bin', 'docs'],
  scripts      => [ File::Spec->catfile( 'bin', 'nopod.pl'  ),
                    File::Spec->catfile( 'bin', 'haspod.pl' )  ],

  # Need default install paths to ensure manpages get generated
  installdirs => 'site',
  config => {
    installsiteman1dir  => catdir($tmp, 'site', 'man', 'man1'),
    installsiteman3dir  => catdir($tmp, 'site', 'man', 'man3'),
  }

);

$mb->add_to_cleanup($destdir);


is( ref $mb->{properties}->{bindoc_dirs}, 'ARRAY', 'bindoc_dirs' );
is( ref $mb->{properties}->{libdoc_dirs}, 'ARRAY', 'libdoc_dirs' );

my %man = (
	   sep  => $mb->manpage_separator,
	   dir1 => 'man1',
	   dir3 => 'man3',
	   ext1 => $mb->config('man1ext'),
	   ext3 => $mb->config('man3ext'),
	  );

my %distro = (
	      'bin/nopod.pl'          => '',
              'bin/haspod.pl'         => "haspod.pl.$man{ext1}",
	      'lib/Simple.pm'         => "Simple.$man{ext3}",
              'lib/Simple/NoPod.pm'   => '',
              'lib/Simple/AllPod.pod' => "Simple$man{sep}AllPod.$man{ext3}",
              'docs/myapp1.pod'        => "myapp1.pod.$man{ext1}",
              'docs/myapp2.pm'        => "myapp2.pm.$man{ext1}",
              'docs/myapp3.pl'        => "myapp3.pl.$man{ext1}",
              'docs/myapp4'           => "myapp4.$man{ext1}",
	     );

%distro = map {$mb->localize_file_path($_), $distro{$_}} keys %distro;

my $lib_path = $mb->localize_dir_path('lib');

# Remove trailing directory delimiter on VMS for compares
$lib_path =~ s/\]// if $^O eq 'VMS';

$mb->dispatch('build');

eval {$mb->dispatch('docs')};
is $@, '';

while (my ($from, $v) = each %distro) {
  if (!$v) {
    ok ! $mb->contains_pod($from), "$from should not contain POD";
    next;
  }

  my $to = File::Spec->catfile('blib', ($from =~ /^[\.\/\[]*lib/ ? 'libdoc' : 'bindoc'), $v);
  ok $mb->contains_pod($from), "$from should contain POD";
  ok -e $to, "Created $to manpage";
}


$mb->dispatch('install');

while (my ($from, $v) = each %distro) {
  next unless $v;
  my $to = File::Spec->catfile
     ($destdir, 'man', $man{($from =~ /^\Q$lib_path\E/ ? 'dir3' : 'dir1')}, $v);
  ok -e $to, "Created $to manpage";
}

$mb->dispatch('realclean');


# revert to a pristine state
$dist->regen( clean => 1 );

my $mb2 = Module::Build->new(
  module_name => $dist->name,
  libdoc_dirs => [qw( foo bar baz )],
);

is( $mb2->{properties}->{libdoc_dirs}->[0], 'foo', 'override libdoc_dirs' );

# Make sure we can find our own action documentation
ok  $mb2->get_action_docs('build');
ok !eval{$mb2->get_action_docs('foo')};

# Make sure those docs are the correct ones
foreach ('testcover', 'disttest') {
  my $docs = $mb2->get_action_docs($_);
  like $docs, qr/=item $_/;
  unlike $docs, qr/\n=/, $docs;
}

