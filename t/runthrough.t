use strict;

use Test; 
BEGIN { plan tests => 18 }
use Module::Build;
use File::Spec;
use File::Path;
use Config;
my $HAVE_YAML = eval {require YAML; 1};

ok(1);
require File::Spec->catfile('t', 'common.pl');

######################### End of black magic.

my $start_dir = Module::Build->cwd;

# Would be nice to just have a 'base_dir' parameter for M::B->new()
my $goto = File::Spec->catdir( $start_dir, 't', 'Sample' );
chdir $goto or die "can't chdir to $goto: $!";

my $build = new Module::Build( module_name => 'Sample',
			       script_files => [ 'script' ],
			       requires => { 'File::Spec' => 0 },
			       license => 'perl' );
ok $build;

# Make sure cleanup files added before create_build_script() get respected
$build->add_to_cleanup('before_script');

eval {$build->create_build_script};
ok $@, '';
ok $build->cleanup_is_flushed;

# The 'cleanup' file doesn't exist yet
ok grep $_ eq 'before_script', $build->cleanup;

$build->add_to_cleanup('save_out');

# The 'cleanup' file now exists
ok grep $_ eq 'before_script', $build->cleanup;
ok grep $_ eq 'save_out',      $build->cleanup;

my $output = eval {
  stdout_of( sub { $build->dispatch('test', verbose => 1) } )
};
ok $output, qr/all tests successful/i;


# We prefix all lines with "| " so Test::Harness doesn't get confused.
print "vvvvvvvvvvvvvvvvvvvvv Sample/test.pl output vvvvvvvvvvvvvvvvvvvvv\n";
$output =~ s/^/| /mg;
print $output;
print "^^^^^^^^^^^^^^^^^^^^^ Sample/test.pl output ^^^^^^^^^^^^^^^^^^^^^\n";

if ($HAVE_YAML) {
  eval {$build->dispatch('disttest')};
  ok $@, '';
  
  # After a test, the distdir should contain a blib/ directory
  ok -e File::Spec->catdir('Sample-0.01', 'blib');
  
  eval {$build->dispatch('distdir')};
  ok $@, '';
  
  # The 'distdir' should contain a lib/ directory
  ok -e File::Spec->catdir('Sample-0.01', 'lib');
  
  # The freshly run 'distdir' should never contain a blib/ directory, or
  # else it could get into the tarball
  ok not -e File::Spec->catdir('Sample-0.01', 'blib');

  # Make sure all of the above was done by the new version of Module::Build
  my $fh = IO::File->new(File::Spec->catfile($goto, 'META.yml'));
  my $contents = do {local $/; <$fh>};
  ok $contents, "/Module::Build version ". $build->VERSION ."/";
  
} else {
  skip "skip YAML.pm is not installed", 1 for 1..6;
}

{
  # Check that a shebang line is rewritten
  my $blib_script = File::Spec->catdir( qw( blib script script ) );
  ok -e $blib_script; 
  
  my $fh = IO::File->new($blib_script);
  my $first_line = <$fh>;
  print "# rewritten shebang?\n$first_line";
  
  ok $first_line ne "#!perl -w\n";
}

{
  # Check PPD
  $build->dispatch('ppd', args => {codebase => '/path/to/codebase'});

  my $ppd = slurp('Sample.ppd');

  # This test is quite a hack since with XML you don't really want to
  # do a strict string comparison, but absent an XML parser it's the
  # best we can do.
  ok $ppd, <<'EOF';
<SOFTPKG NAME="Sample" VERSION="0,01,0,0">
    <TITLE>Sample</TITLE>
    <ABSTRACT>Foo foo sample foo</ABSTRACT>
    <AUTHOR>Sample Man &lt;sample@example.com&gt;</AUTHOR>
    <IMPLEMENTATION>
        <DEPENDENCY NAME="File-Spec" VERSION="0,0,0,0" />
        <CODEBASE HREF="/path/to/codebase" />
    </IMPLEMENTATION>
</SOFTPKG>
EOF
}


eval {$build->dispatch('realclean')};
ok $@, '';

# Clean up
File::Path::rmtree( 'Sample-0.01', 0, 0 );
