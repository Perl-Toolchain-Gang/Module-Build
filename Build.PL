use strict;

# On some platforms (*ahem*, MacPerl 5.6.1) "use lib qw(lib);" doesn't
# find the local "lib" directory, so we use File::Spec to do it properly.
use File::Spec 0.82;
use lib File::Spec->catdir('lib');          # use our self to install
# XXX This doesn't carry over to sub processes
use lib File::Spec->catdir('t', 'bundled'); # use bundled modules
use lib File::Spec->catdir('t', 'lib');     # our utilities

# We use Module::Build to test & install itself.
use Module::Build;

# <remove_me> This code is only present for M::B developers, not on CPAN
use lib File::Spec->catdir('inc');
# A custom builder that does some special stuff during the 'dist' phase
use ModuleBuildBuilder;
# </remove_me>

my $build = ModuleBuildBuilder->new(
  module_name => 'Module::Build',
  license     => 'perl',
  build_requires        => {
    'File::Temp'            => 0.15,    # tmpdir() + fixes
    'Test::More'            => 0.49,
    'Test::Harness'         => 3.16,    # PERL5LIB fixes
  },
  requires    => {
    'perl'                  => '5.006001',
    'Data::Dumper'          => 0,
    'File::Basename'        => 0,
    'File::Compare'         => 0,
    'File::Copy'            => 0,
    'File::Find'            => 0,
    'File::Path'            => 0,
    'File::Spec'            => ($^O eq 'MSWin32' ? 3.30 : '0.82'), # rel2abs()
    'ExtUtils::Install'     => 0,
    'ExtUtils::Manifest'    => 0,
    'ExtUtils::Mkbootstrap' => 0,
    'IO::File'              => 1.13, # fixes binmode bug on perl < 5.8.8
    'Cwd'                   => 0,
    'Text::Abbrev'          => 0,
    'Text::ParseWords'      => 0,
    'Getopt::Long'          => 0,
    'Test::Harness'         => 0,
  },
  recommends => {
    'Archive::Tar'       => 1.08,
    'ExtUtils::CBuilder' => 0.260301, # numerous bug fixes
    'ExtUtils::Install'  => 0.30,
    'ExtUtils::ParseXS'  => 2.21,
    'Pod::Readme'        => 0.04,
    'Module::Signature'  => 0.21,
    'version'            => 0.74,
  },
  recursive_test_files => 1,
  sign          => 1,
  create_readme => 1,
  create_license => 1,

  # overwrite the M::B that shipped in core
  installdirs   => ($] >= 5.009004 ? 'core' : 'site'),
  
  # Some CPANPLUS::Dist::Build versions need to allow mismatches 
  # On logic: thanks to Module::Install, CPAN.pm must set both keys, but
  # CPANPLUS sets only the one
  allow_mb_mismatch => ( 
    $ENV{PERL5_CPANPLUS_IS_RUNNING} && ! $ENV{PERL5_CPAN_IS_RUNNING} ? 1 : 0
  ),

  auto_features => {
    YAML_support => {
      description => "Use YAML::Tiny to write META.yml files",
      requires    => {'YAML::Tiny' => 1.38},
    },
    C_support => {
      description => "Compile/link C & XS code",
      requires    => {'ExtUtils::CBuilder' => 0.260301,},
      recommends  => {'ExtUtils::ParseXS' => 2.21,},
    },
    manpage_support => {
      description => "Create Unix man pages",
      requires    => {'Pod::Man' => 0},
    },
    HTML_support => {
      description => "Create HTML documentation",
      requires    => {'Pod::Html' => 0},
    },
  },

  add_to_cleanup => ['t/Sample/pod2htm*'],
  script_files   => ['scripts/config_data'],
  meta_merge     => {
    resources => {
      homepage => 'http://sourceforge.net/projects/module-build',
      bugtracker =>
        'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Module-Build',
      MailingList => 'mailto:module-build@perl.org',
      repository  => 'http://svn.perl.org/modules/Module-Build/'
    }
  },
);

$build->create_build_script;

# vim:ts=2:sw=2:et:sta
