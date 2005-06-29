#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use Test::More tests => 28;

my $have_yaml = Module::Build->current->feature('YAML_support');


use File::Spec ();
my $common_pl = File::Spec->catfile( 't', 'common.pl' );
require $common_pl;


#########################

use Cwd ();
my $cwd = Cwd::cwd;
my $tmp = File::Spec->catdir( $cwd, 't', '_tmp' );

use DistGen;
my $dist = DistGen->new( dir => $tmp );
$dist->remove_file( 't/basic.t' );
$dist->change_file( 'Build.PL', <<'---' );
use Module::Build;

my $build = new Module::Build(
  module_name => 'Simple',
  scripts     => [ 'script' ],
  license     => 'perl',
  requires    => { 'File::Spec' => 0 },
);
$build->create_build_script;
---
$dist->add_file( 'script', <<'---' );
#!perl -w
print "Hello, World!\n";
---
$dist->add_file( 'test.pl', <<'---' );
#!/usr/bin/perl

use Test;
plan tests => 2;

ok 1;

require Module::Build;
ok $INC{'Module/Build.pm'}, qr/blib/, 'Module::Build should be loaded from blib';
print "# Cwd: ", Module::Build->cwd, "\n";
print "# \@INC: (@INC)\n";
print "Done.\n";  # t/compat.t looks for this
---
$dist->add_file( 'lib/Simple/Script.PL', <<'---' );
#!perl -w

my $filename = shift;
open FH, "> $filename" or die "Can't create $filename: $!";
print FH "Contents: $filename\n";
close FH;
---
$dist->regen;

chdir( $dist->dirname ) or die "Can't chdir to '@{[$dist->dirname]}': $!";

#########################

use Module::Build;
ok(1);

like $INC{'Module/Build.pm'}, qr/\bblib\b/, "Make sure version from blib/ is loaded";

#########################

my $build = Module::Build->new_from_context;
ok $build;
is $build->license, 'perl';

# Make sure cleanup files added before create_build_script() get respected
$build->add_to_cleanup('before_script');

eval {$build->create_build_script};
ok ! $@;
ok -e $build->build_script;

is $build->dist_dir, 'Simple-0.01';

# The 'cleanup' file doesn't exist yet
ok grep {$_ eq 'before_script'} $build->cleanup;

$build->add_to_cleanup('save_out');

# The 'cleanup' file now exists
ok grep {$_ eq 'before_script'} $build->cleanup;
ok grep {$_ eq 'save_out'     } $build->cleanup;

my $output = eval {
  stdout_of( sub { $build->dispatch('test', verbose => 1) } )
};
ok ! $@;
like $output, qr/all tests successful/i;

# This is the output of lib/Simple/Script.PL
ok -e $build->localize_file_path('lib/Simple/Script');


# We prefix all lines with "| " so Test::Harness doesn't get confused.
print "vvvvvvvvvvvvvvvvvvvvv Simple/test.pl output vvvvvvvvvvvvvvvvvvvvv\n";
$output =~ s/^/| /mg;
print $output;
print "^^^^^^^^^^^^^^^^^^^^^ Simple/test.pl output ^^^^^^^^^^^^^^^^^^^^^\n";

SKIP: {
  skip( 'YAML_support feature is not enabled', 7 ) unless $have_yaml;

  eval {$build->dispatch('disttest')};
  ok ! $@;
  
  # After a test, the distdir should contain a blib/ directory
  ok -e File::Spec->catdir('Simple-0.01', 'blib');
  
  eval {$build->dispatch('distdir')};
  ok ! $@;
  
  # The 'distdir' should contain a lib/ directory
  ok -e File::Spec->catdir('Simple-0.01', 'lib');
  
  # The freshly run 'distdir' should never contain a blib/ directory, or
  # else it could get into the tarball
  ok ! -e File::Spec->catdir('Simple-0.01', 'blib');

  # Make sure all of the above was done by the new version of Module::Build
  my $fh = IO::File->new(File::Spec->catfile($dist->dirname, 'META.yml'));
  my $contents = do {local $/; <$fh>};
  $contents =~ /Module::Build version ([0-9_.]+)/m;
  is $1, $build->VERSION, "Check version used to create META.yml: $1 == " . $build->VERSION;

  SKIP: {
    skip( "not sure if we can create a tarball on this platform", 1 )
      unless $build->check_installed_status('Archive::Tar', 0) ||
	     $build->isa('Module::Build::Platform::Unix');

    $build->add_to_cleanup($build->dist_dir . ".tar.gz");
    eval {$build->dispatch('dist')};
    ok ! $@;
  }

}

{
  # Make sure the 'script' file was recognized as a script.
  my $scripts = $build->script_files;
  ok $scripts->{script};
  
  # Check that a shebang line is rewritten
  my $blib_script = File::Spec->catdir( qw( blib script script ) );
  ok -e $blib_script;
  
  my $fh = IO::File->new($blib_script);
  my $first_line = <$fh>;
  print "# rewritten shebang?\n$first_line";
  
  isnt $first_line, "#!perl -w\n";
}

{
  # Check PPD
  $build->dispatch('ppd', args => {codebase => '/path/to/codebase'});

  my $ppd = slurp('Simple.ppd');

  # This test is quite a hack since with XML you don't really want to
  # do a strict string comparison, but absent an XML parser it's the
  # best we can do.
  is $ppd, <<'EOF';
<SOFTPKG NAME="Simple" VERSION="0,01,0,0">
    <TITLE>Simple</TITLE>
    <ABSTRACT>Perl extension for blah blah blah</ABSTRACT>
    <AUTHOR>A. U. Thor, a.u.thor@a.galaxy.far.far.away</AUTHOR>
    <IMPLEMENTATION>
        <DEPENDENCY NAME="File-Spec" VERSION="0,0,0,0" />
        <CODEBASE HREF="/path/to/codebase" />
    </IMPLEMENTATION>
</SOFTPKG>
EOF
}


eval {$build->dispatch('realclean')};
ok ! $@;

ok ! -e $build->build_script;
ok ! -e $build->config_dir;
ok ! -e $build->dist_dir;


# cleanup
chdir( $cwd ) or die "Can''t chdir to '$cwd': $!";
$dist->remove;

use File::Path;
rmtree( $tmp );
