use Test; 
BEGIN { plan tests => 16 }
use Module::Build;
use File::Spec;
use File::Path;
my $HAVE_YAML = eval {require YAML; 1};
my $HAVE_SIGNATURE = eval {require Module::Signature; 1};

ok(1);
require File::Spec->catfile('t', 'common.pl');

######################### End of black magic.

# So 'test' and 'disttest' can see the not-yet-installed Module::Build.
unshift @INC,     # For 'test'
$ENV{PERL5LIB} =  # For 'disttest'
File::Spec->catdir( Module::Build->cwd, 'blib', 'lib' );

my $goto = File::Spec->catdir( Module::Build->cwd, 't', 'Sample' );
chdir $goto or die "can't chdir to $goto: $!";

my $build = new Module::Build( module_name => 'Sample', scripts => [ 'script' ],
			       license => 'perl' );
ok $build;

# Make sure cleanup files added before create_build_script() get respected
$build->add_to_cleanup('before_script');

eval {$build->create_build_script};
ok $@, '';

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

if (0 && $HAVE_SIGNATURE) {
  my $sigfile = File::Spec->catdir('Sample-0.01', 'SIGNATURE');
  $build->add_to_cleanup( $sigfile );

  chdir 'Sample-0.01' or warn "Couldn't chdir to Sample-0.01: $!";
  eval {$build->dispatch('distsign')};
  ok $@, '';
  chdir $goto;

  ok -e $sigfile;
} else {
  # skip "skip Module::Signature is not installed", 1 for 1..2;
}

{
  my $blib_script = File::Spec->catdir( qw( blib script script ) );
  ok -e $blib_script; 
  
  my $fh = IO::File->new($blib_script);
  my $first_line = <$fh>;
  print "# rewritten shebang?\n$first_line";
  
  ok $first_line ne "#!perl -w\n";
}

eval {$build->dispatch('realclean')};
ok $@, '';

# Clean up
File::Path::rmtree( 'Sample-0.01', 0, 0 );
