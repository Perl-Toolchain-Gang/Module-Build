######################### We start with some black magic to print on failure.

use strict;
use Test;
use Config;
use Module::Build;
use File::Spec;

my $common_pl = File::Spec->catfile('t', 'common.pl');
require $common_pl;

{ local $SIG{__WARN__} = sub {};

  my $have_c_compiler;
  stderr_of( sub {$have_c_compiler = Module::Build->current->have_c_compiler} );
  print("1..0 # Skipped: no compiler found\n"), exit(0) unless $have_c_compiler;
}

plan tests => 12;

######################### End of black magic.

# Pretend we're in the t/XSTest/ subdirectory
my $build_dir = File::Spec->catdir('t','XSTest');
chdir $build_dir or die "Can't change to $build_dir : $!";

my $m = Module::Build->new_from_context;
ok(1);

eval {$m->dispatch('clean')};
ok $@, '';

eval {$m->dispatch('build')};
ok $@, '';

{
  # Try again in a subprocess 
  eval {$m->dispatch('clean')};
  ok $@, '';

  $m->create_build_script;
  ok -e 'Build';
  
  eval {$m->run_perl_script('Build')};
  ok $@, '';
}

# We can't be verbose in the sub-test, because Test::Harness will
# think that the output is for the top-level test.
eval {$m->dispatch('test')};
ok $@, '';

{
  $m->dispatch('ppd', args => {codebase => '/path/to/codebase-xs'});

  my $ppd = slurp('XSTest.ppd');

  my $perl_version = Module::Build::PPMMaker->_ppd_version($m->perl_version);
  my $varchname = Module::Build::PPMMaker->_varchname($m->config);

  # This test is quite a hack since with XML you don't really want to
  # do a strict string comparison, but absent an XML parser it's the
  # best we can do.
  ok $ppd, <<"EOF";
<SOFTPKG NAME="XSTest" VERSION="0,01,0,0">
    <TITLE>XSTest</TITLE>
    <ABSTRACT>Perl extension for blah blah blah</ABSTRACT>
    <AUTHOR>A. U. Thor, a.u.thor\@a.galaxy.far.far.away</AUTHOR>
    <IMPLEMENTATION>
        <PERLCORE VERSION="$perl_version" />
        <OS NAME="$^O" />
        <ARCHITECTURE NAME="$varchname" />
        <CODEBASE HREF="/path/to/codebase-xs" />
    </IMPLEMENTATION>
</SOFTPKG>
EOF
}

if ($m->os_type eq 'Unix') {
  eval {$m->dispatch('clean')};
  ok $@, '';
  
  local $m->{config}{ld} = "FOO=BAR $m->{config}{ld}";
  eval {$m->dispatch('build')};
  ok $@, '';
} else {
  skip_subtest("skipping a couple Unixish-only tests") for 1..2;
}

eval {$m->dispatch('realclean')};
ok $@, '';

# Make sure blib/ is gone after 'realclean'
ok not -e 'blib';

