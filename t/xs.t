######################### We start with some black magic to print on failure.

use strict;
use Test;
use Config;
use Module::Build;
use File::Spec;

print("1..0 # Skipped: no compiler found\n"), exit(0) unless Module::Build->current->have_c_compiler;
plan tests => 10;

require File::Spec->catfile('t', 'common.pl');

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
        <OS VALUE="$^O" />
        <ARCHITECTURE NAME="$Config{archname}" />
        <CODEBASE HREF="/path/to/codebase-xs" />
    </IMPLEMENTATION>
</SOFTPKG>
EOF
}

eval {$m->dispatch('realclean')};
ok $@, '';

# Make sure blib/ is gone after 'realclean'
ok not -e 'blib';

