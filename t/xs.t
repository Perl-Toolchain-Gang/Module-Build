#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use Test::More;


use File::Spec ();
my $common_pl = File::Spec->catfile( 't', 'common.pl' );
require $common_pl;


use Module::Build;

{ local $SIG{__WARN__} = sub {};

  my $mb = Module::Build->current;
  $mb->verbose( 0 );

  my $have_c_compiler;
  stderr_of( sub {$have_c_compiler = $mb->have_c_compiler} );

  if ( ! $mb->feature('C_support') ) {
    plan skip_all => 'C_support not enabled';
  } elsif ( !$have_c_compiler ) {
    plan skip_all => 'C_support enabled, but no compiler found';
  } else {
    plan tests => 18;
  }
}

#########################


use Cwd ();
my $cwd = Cwd::cwd;
my $tmp = File::Spec->catdir( $cwd, 't', '_tmp' );

use DistGen;
my $dist = DistGen->new( dir => $tmp, xs => 1 );
$dist->regen;

chdir( $dist->dirname ) or die "Can't chdir to '@{[$dist->dirname]}': $!";
my $mb = Module::Build->new_from_context( skip_rcfile => 1 );


eval {$mb->dispatch('clean')};
is $@, '';

eval {$mb->dispatch('build')};
is $@, '';

{
  use DynaLoader;
  my $librefs_highwater = @DynaLoader::dl_librefs;

  # Make sure it actually works
  eval 'use blib; require ' . $dist->name;
  is $@, '';
  
  my $sub = $dist->name->can('ok');
  ok $sub, "ok() function should be defined";
  is $sub->(), 'ok', "The ok() function should return the string 'ok'";
  
  $sub = $dist->name->can('version');
  ok $sub, "version() function should be defined";
  is $sub->(), "0.01", "version() should return the string '0.01'";
  
  $sub = $dist->name->can('xs_version');
  ok $sub, "xs_version() function should be defined";
  is $sub->(), "0.01", "xs_version() should return the string '0.01'";

  # unload the dll so it can be unlinked
  DynaLoader::dl_unload_file($DynaLoader::dl_librefs[$librefs_highwater])
    if DynaLoader->can('dl_unload_file');
}

{
  # Try again in a subprocess 
  eval {$mb->dispatch('clean')};
  is $@, '';

  $mb->create_build_script;
  ok -e 'Build';

  eval {$mb->run_perl_script('Build')};
  is $@, '';
}

# We can't be verbose in the sub-test, because Test::Harness will
# think that the output is for the top-level test.
eval {$mb->dispatch('test')};
is $@, '';

{
  $mb->dispatch('ppd', args => {codebase => '/path/to/codebase-xs'});

  (my $dist_filename = $dist->name) =~ s/::/-/g;
  my $ppd = slurp($dist_filename . '.ppd');

  my $perl_version = Module::Build::PPMMaker->_ppd_version($mb->perl_version);
  my $varchname = Module::Build::PPMMaker->_varchname($mb->config);

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
      unless $mb->os_type eq 'Unix';

  eval {$mb->dispatch('clean')};
  is $@, '';

  local $mb->{config}{ld} = "FOO=BAR $mb->{config}{ld}";
  eval {$mb->dispatch('build')};
  is $@, '';
}

eval {$mb->dispatch('realclean')};
is $@, '';

# Make sure blib/ is gone after 'realclean'
ok ! -e 'blib';


# cleanup
chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
$dist->remove;

use File::Path;
rmtree( $tmp );
