#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use Test::More;


use File::Spec ();
my $common_pl = File::Spec->catfile( 't', 'common.pl' );
require $common_pl;


use Module::Build;

{ local $SIG{__WARN__} = sub {};

  my $m = Module::Build->current;
  $m->verbose( 0 );

  my $have_c_compiler;
  stderr_of( sub {$have_c_compiler = $m->have_c_compiler} );

  if ( ! $m->feature('C_support') ) {
    plan skip_all => 'C_support not enabled';
  } elsif ( !$have_c_compiler ) {
    plan skip_all => 'C_support enabled, but no compiler found';
  } else {
    plan tests => 11;
  }
}

#########################


use Cwd ();
my $cwd = Cwd::cwd;

use DistGen;
my $dist = DistGen->new( xs_module => 1 );
$dist->regen;

chdir( $dist->dirname ) or die "Can't chdir to '@{[$dist->dirname]}': $!";
my $m = Module::Build->new_from_context( skip_rcfile => 1 );


eval {$m->dispatch('clean')};
ok not $@;

eval {$m->dispatch('build')};
ok not $@;

{
  # Try again in a subprocess 
  eval {$m->dispatch('clean')};
  ok not $@;

  $m->create_build_script;
  ok -e 'Build';

  eval {$m->run_perl_script('Build')};
  ok not $@;
}

# We can't be verbose in the sub-test, because Test::Harness will
# think that the output is for the top-level test.
eval {$m->dispatch('test')};
ok not $@;

{
  $m->dispatch('ppd', args => {codebase => '/path/to/codebase-xs'});

  (my $dist_filename = $dist->name) =~ s/::/-/g;
  my $ppd = slurp($dist_filename . '.ppd');

  my $perl_version = Module::Build::PPMMaker->_ppd_version($m->perl_version);
  my $varchname = Module::Build::PPMMaker->_varchname($m->config);

  # This test is quite a hack since with XML you don't really want to
  # do a strict string comparison, but absent an XML parser it's the
  # best we can do.
  is $ppd, <<"EOF";
<SOFTPKG NAME="$dist_filename" VERSION="0,01,0,0">
    <TITLE>@{[$dist->name]}</TITLE>
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

SKIP: {
  skip( "skipping a couple Unixish-only tests", 2 )
      unless $m->os_type eq 'Unix';

  eval {$m->dispatch('clean')};
  ok not $@;

  local $m->{config}{ld} = "FOO=BAR $m->{config}{ld}";
  eval {$m->dispatch('build')};
  ok not $@;
}

eval {$m->dispatch('realclean')};
ok not $@;

# Make sure blib/ is gone after 'realclean'
ok not -e 'blib';


#########################
# cleanup

chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
$dist->remove;
