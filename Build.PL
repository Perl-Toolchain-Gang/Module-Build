use strict;

# On some platforms (*ahem*, MacPerl 5.6.1) "use lib qw(lib);" doesn't
# find the local "lib" directory, so we use File::Spec to do it properly.
use File::Spec;
use lib File::Spec->catdir('lib');

# We use Module::Build to test & install itself.
use Module::Build;

# <remove_me> This code is only present for M::B developers, not on CPAN
use lib File::Spec->catdir('inc');
# A custom builder that does some special stuff during the 'dist' phase
use ModuleBuildBuilder;
# </remove_me>

my $build = new ModuleBuildBuilder
  (
   module_name => 'Module::Build',   
   license => 'perl',
   requires => {
		'perl'           => '5.005_03',
		'Data::Dumper'   => 0,
		'File::Basename' => 0,
		'File::Compare'  => 0,
		'File::Copy'     => 0,
		'File::Find'     => 0,
		'File::Path'     => 0,
		'File::Spec'     => 0,
		'ExtUtils::Install' => 0,
		'ExtUtils::Manifest' => 0,
		'ExtUtils::Mkbootstrap' => 0,
		'IO::File'       => 0,
		'Cwd'            => 0,
		'Text::ParseWords' => 0,
		'Getopt::Long'   => 0,
	       },
   recommends => {
		  'Archive::Tar' => '1.08',
		  'ExtUtils::Install' => 0.30,
		  'ExtUtils::ParseXS' => 2.02,
		  'Pod::Text' => 0,
		  'Module::Signature' => 0.21,
		 },
   build_requires => {
		      Test => 0,
		     },
   sign => 1,
   create_readme => 1,

   auto_features => {
		     YAML_support =>
		     {
		      description => "Can write fully-functional META.yml files",
		      requires => { YAML => ' >= 0.35, < 0.49 ' },
		     },
		     C_support =>
		     {
		      description => "Can compile/link C & XS code",
		      requires => { 'ExtUtils::CBuilder' => 0.02 },
		     },
		     manpage_support =>
		     {
		      description => "Can create Unix man pages",
		      requires => { 'Pod::Man' => 0 },
		     },
		     HTML_support =>
		     {
		      description => "Can create HTML documentation",
		      requires => { 'Pod::Html' => 0 },
		     },
		    },

   add_to_cleanup => ['t/Sample/pod2htm*'],
   script_files => ['scripts/config_data'],
  );

$build->create_build_script;
$build->notes(foo => 'bar');   # We set this here and verify it in t/notes.t
