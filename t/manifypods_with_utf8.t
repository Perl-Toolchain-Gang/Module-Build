package ManifypodsWithUtf8;
use strict;
use Test::More;

use lib 't/lib';
blib_load('Module::Build');
blib_load('Module::Build::ConfigData');

SKIP: {
   unless ( Module::Build::ConfigData->feature('manpage_support') ) {
     skip 'manpage_support feature is not enabled';
   }
}

use MBTest tests => 1;
use File::Spec::Functions qw( catdir );

use Cwd ();
my $cwd = Cwd::cwd;
my $tmp = MBTest->tmpdir;

use DistGen;
my $dist = DistGen->new( dir => $tmp );
$dist->add_file( 'lib/Simple/PodWithUtf8.pod', <<'---' );
=head1 NAME

Simple::PodWithUtf8 - POD with some (ç á à ô) special chars

=cut
---
$dist->regen;
$dist->chdir_in;

my $destdir = catdir($cwd, 't', 'install_test' . $$);

my $mb = Module::Build->new(
			    module_name      => $dist->name,
			    install_base     => $destdir,

			    # need default install paths to ensure manpages & HTML get generated
			    installdirs => 'site',
			    extra_manify_args => { utf8 => 1 },
			   );
$mb->add_to_cleanup($destdir);


$mb->dispatch('build');
my $sep = $mb->manpage_separator;
my $ext3 = $mb->config('man3ext');
my $to = File::Spec->catfile('blib', 'libdoc', "Simple${sep}PodWithUtf8.${ext3}");

open my $pod, '<:utf8', $to;
undef $/; my $pod_content = <$pod>;
close $pod;

ok $pod_content =~ qr/ \(ç á à ô\) /, "POD should contain special characters";

