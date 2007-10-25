use strict;

# On some platforms (*ahem*, MacPerl 5.6.1) "use lib qw(lib);" doesn't
# find the local "lib" directory, so we use File::Spec to do it properly.
use File::Spec 0.82;
use lib File::Spec->catdir('lib');          # use our self to install
# XXX we're not actually able to use the bundled copy
use lib File::Spec->catdir('t', 'bundled'); # use bundled Test::More
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
  requires    => {
    'perl'                  => '5.005_04',
    'Data::Dumper'          => 0,
    'File::Basename'        => 0,
    'File::Compare'         => 0,
    'File::Copy'            => 0,
    'File::Find'            => 0,
    'File::Path'            => 0,
    'File::Spec'            => '0.82',    # rel2abs()
    'ExtUtils::Install'     => 0,
    'ExtUtils::Manifest'    => 0,
    'ExtUtils::Mkbootstrap' => 0,
    'IO::File'              => 0,
    'Cwd'                   => 0,
    'Text::Abbrev'          => 0,
    'Text::ParseWords'      => 0,
    'Getopt::Long'          => 0,
    'Test::Harness'         => 0,
  },
  recommends => {
    'Archive::Tar'       => '1.08',
    'ExtUtils::CBuilder' => 0.15,
    'ExtUtils::Install'  => 0.30,
    'ExtUtils::ParseXS'  => 1.02,
    'Pod::Readme'        => 0.04,
    'Module::Signature'  => 0.21,
    'version'            => 0.74,
  },
  sign          => 1,
  create_readme => 1,

  # overwrite the M::B that shipped in core
  installdirs   => ($] >= 5.009004 ? 'core' : 'site'),

  auto_features => {
    YAML_support => {
      description => "Use YAML.pm to write META.yml files",
      requires    => {YAML => ' >= 0.35, != 0.49_01 '},
    },
    C_support => {
      description => "Compile/link C & XS code",
      requires    => {'ExtUtils::CBuilder' => 0.15,},
      recommends  => {'ExtUtils::ParseXS' => 1.02,},
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
