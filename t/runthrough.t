use strict;

use Test; 
BEGIN { plan tests => 28 }
use Module::Build;
use File::Spec;
use File::Path;
use Config;

ok(1);
ok $INC{'Module/Build.pm'}, '/blib/', "Make sure version from blib/ is loaded";


require File::Spec->catfile('t', 'common.pl');

######################### End of black magic.

my $have_yaml = Module::Build->current->feature('YAML_support');

my $start_dir = Module::Build->cwd;

# Would be nice to just have a 'base_dir' parameter for M::B->new()
my $goto = File::Spec->catdir( $start_dir, 't', 'Sample' );
chdir $goto or die "can't chdir to $goto: $!";

my $build = Module::Build->new_from_context();
ok $build;
ok $build->license, 'perl';

# Make sure cleanup files added before create_build_script() get respected
$build->add_to_cleanup('before_script');

eval {$build->create_build_script};
ok $@, '';
ok -e $build->build_script, 1;

ok $build->dist_dir, 'Sample-0.01';

# The 'cleanup' file doesn't exist yet
ok grep $_ eq 'before_script', $build->cleanup;

$build->add_to_cleanup('save_out');

# The 'cleanup' file now exists
ok grep $_ eq 'before_script', $build->cleanup;
ok grep $_ eq 'save_out',      $build->cleanup;

my $output = eval {
  stdout_of( sub { $build->dispatch('test', verbose => 1) } )
};
ok $@, '';
ok $output, qr/all tests successful/i;

# This is the output of lib/Sample/Script.PL
ok -e $build->localize_file_path('lib/Sample/Script');


# We prefix all lines with "| " so Test::Harness doesn't get confused.
print "vvvvvvvvvvvvvvvvvvvvv Sample/test.pl output vvvvvvvvvvvvvvvvvvvvv\n";
$output =~ s/^/| /mg;
print $output;
print "^^^^^^^^^^^^^^^^^^^^^ Sample/test.pl output ^^^^^^^^^^^^^^^^^^^^^\n";

if ($have_yaml) {
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
  $contents =~ /Module::Build version ([0-9_.]+)/m;
  ok $1 == $build->VERSION, 1, "Check version used to create META.yml: $1 == " . $build->VERSION;
  
  if ($build->check_installed_status('Archive::Tar', 0)
      or $build->isa('Module::Build::Platform::Unix')) {
    $build->add_to_cleanup($build->dist_dir . ".tar.gz");
    eval {$build->dispatch('dist')};
    ok $@, '';
    
  } else {
    skip_subtest("not sure if we can create a tarball on this platform");
  }

} else {
  skip_subtest("YAML_support feature is not enabled") for 1..7;
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

ok not -e $build->build_script;
ok not -e $build->config_dir;
ok not -e $build->dist_dir;
