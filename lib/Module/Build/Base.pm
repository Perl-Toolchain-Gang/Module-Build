package Module::Build::Base;

use strict;
use Config;
use File::Copy ();
use File::Find ();
use File::Path ();
use File::Basename ();
use File::Spec ();

sub new {
  my $package = shift;
  my $self = bless {
		    # Don't save these defaults in config_dir.
		    build_script => 'Build',
		    config_dir => '_build',
		    @_,
		    new_cleanup => {},
		   }, $package;
  
  my ($action, $args) = $self->cull_args(@ARGV);
  die "Too early to specify a build action '$action'.  Do ./$self->{build_script} $action instead.\n"
    if $action;

  $self->{args} = {%Config, @_, %$args};

  $self->find_version;
  $self->write_config;
  
  $self->check_manifest;
  
  return $self;
}

sub resume {
  my $package = shift;
  my $self = bless {@_}, $package;
  
  $self->read_config;
  $self->{new_cleanup} = {};
  return $self;
}

sub find_version {
  my ($self) = @_;
  return if exists $self->{args}{module_version};
  
  if (exists $self->{args}{module_version_from}) {
    my $version = $self->version_from_file($self->{args}{module_version_from});
    $self->{args}{module_version} = $version;
    delete $self->{args}{module_version_from};
  } else {
    # Try to find the version in 'module_name'
    my $chief_file = $self->module_name_to_file($self->{args}{module_name});
    die "Can't find module '$self->{args}{module_name}' for version check" unless defined $chief_file;
    $self->{args}{module_version} = $self->version_from_file($chief_file);
  }
}

sub module_name_to_file {
  my ($self, $mod) = @_;
  my $file = File::Spec->catfile(split '::', $mod);
  foreach ('lib', @INC) {
    my $testfile = File::Spec->catfile($_, $file);
    return $testfile if -e $testfile and !-d _;  # For stuff like ExtUtils::xsubpp
    return "$testfile.pm" if -e "$testfile.pm";
  }
  return;
}

sub version_from_file {
  my ($self, $file) = @_;

  # Some of this code came from the ExtUtils:: hierarchy.
  open my($fh), $file or die "Can't open '$file' for version: $!";
  while (<$fh>) {
    if ( /([\$*])(([\w\:\']*)\bVERSION)\b.*\=/ ) {
      my $eval = qq{
		    package Module::Build::Base::_version;
		    no strict;
		    
		    local $1$2;
		    \$$2=undef; do {
		      $_
		    }; \$$2
		   };
      no warnings;
      my $result = eval $eval;
      die "Could not eval '$_' in '$file': $@" if $@;
      return $result;
    }
  }
  die "Couldn't find version string in '$file'";
}

sub add_to_cleanup {
  my $self = shift;
  @{$self->{new_cleanup}}{@_} = ();
}

sub write_cleanup {
  my ($self) = @_;
  return unless %{$self->{new_cleanup}};  # no new files
  
  # Merge the new parameters into the old
  @{ $self->{cleanup} }{ keys %{ $self->{new_cleanup} } } = ();
  
  # Write to the cleanup file
  my $cleanup_file = $self->config_file('cleanup');
  open my $fh, ">$cleanup_file" or die "Can't write '$cleanup_file': $!";
  print $fh map {"$_\n"} sort keys %{$self->{cleanup}};
}

sub config_file {
  my ($self) = @_;
  return File::Spec->catfile($self->{config_dir}, $_[1]);
}

sub read_config {
  my ($self) = @_;
  
  my $file = $self->config_file('build_params');
  open my $fh, $file or die "Can't read '$file': $!";
  
  while (<$fh>) {
    if (/^(\w+)$/) {
      $self->{args}{$1} = undef;
    } elsif (/^(\w+)=(.*)/) {
      $self->{args}{$1} = $2;
    }
  }
  close $fh;
  
  my $cleanup_file = $self->config_file('cleanup');
  $self->{cleanup} = {};
  if (-e $cleanup_file) {
    open my $fh, $cleanup_file or die "Can't read '$file': $!";
    my @files = <$fh>;
    chomp @files;
    @{$self->{cleanup}}{@files} = ();
  }
}

sub write_config {
  my ($self) = @_;
  
  $self->delete_filetree($self->{config_dir});
  mkdir $self->{config_dir}, 0777
    or die "Can't mkdir $self->{config_dir}: $!";
  
  my $file = $self->config_file('build_params');
  open my $fh, ">$file" or die "Can't create '$file': $!";
  
  foreach my $key (sort keys %{$self->{args}} ) {
    if (!defined $self->{args}{$key}) {
      print $fh "$key\n";

    } elsif ($self->{args}{$key} =~ /\n/) {
      warn "Sorry, can't handle newlines in config data '$key' (yet)\n";

    } else {
      print $fh "$key=$self->{args}{$key}\n";
    }
  }
}

sub rm_previous_build_script {
  my $self = shift;
  if (-e $self->{build_script}) {
    print "Removing previous file '$self->{build_script}'\n";
    unlink $self->{build_script} or die "Couldn't remove '$self->{build_script}': $!";
  }
}

sub make_build_script_executable {
  chmod 0544, $_[0]->{build_script};
}

sub print_build_script {
  my ($self, $fh) = @_;
  
  my $quoted_INC = join ', ', map "'$_'", @INC;
  my $build_dir = File::Spec->rel2abs(File::Basename::dirname($0));
  my $build_package = ref($self);

  print $fh <<EOF;
$self->{args}{startperl} -w

BEGIN { \@INC = ($quoted_INC) }

chdir('$build_dir');
use $build_package;

my \$build = resume $build_package (
  config_dir => '$self->{config_dir}',
  build_script => '$self->{build_script}',
);
eval {\$build->dispatch};
my \$err = \$@;
\$build->write_cleanup;
die \$err if \$err;

EOF
}

sub create_build_script {
  my ($self) = @_;
  
  $self->rm_previous_build_script;

  print("Creating new '$self->{build_script}' script for ",
	"'$self->{args}{module_name}' version '$self->{args}{module_version}'\n");
  open my $fh, ">$self->{build_script}" or die "Can't create '$self->{build_script}': $!";
  $self->print_build_script($fh);
  close $fh;
  
  $self->make_build_script_executable;

  return 1;
}

sub check_manifest {
  # Stolen nearly verbatim from MakeMaker.  But ExtUtils::Manifest
  # could easily be re-written into a modern Perl dialect.

  print "Checking whether your kit is complete...\n";
  require ExtUtils::Manifest;
  $ExtUtils::Manifest::Quiet = 1;
  
  if (my @missed = ExtUtils::Manifest::manicheck()) {
    print "Warning: the following files are missing in your kit:\n";
    print "\t", join "\n\t", @missed;
    print "\n";
    print "Please inform the author.\n";
  } else {
    print "Looks good\n";
  }
}

sub dispatch {
  my $self = shift;
  
  if (@_) {
    $self->{action} = shift;
    $self->{args} = {%{$self->{args}}, @_};
  } else {
    my ($action, $args) = $self->cull_args(@ARGV);
    $self->{action} = $action || 'build';
    $self->{args} = {%{$self->{args}}, %$args};
  }

  my $action = "ACTION_$self->{action}";
  if ($self->can($action)) {
    #print ref($self),"->$action\n";
    $self->$action;
  } else {
    print "No method '$action' defined.\n";
  }
}

sub cull_args {
  my $self = shift;
  my ($action, %args);
  foreach (@_) {
    if ( /^(\w+)=(.*)/ ) {
      $args{$1} = $2;
    } elsif ( /^(\w+)$/ ) {
      die "Error: multiple build actions given: '$action' and '$1'" if $action;
      $action = $1;
    } else {
      die "Malformed build parameter '$_'";
    }
  }
  return ($action, \%args);
}

sub ACTION_help {
  my ($self) = @_;
  # XXX the list of actions should be autogenerated somehow.
  
  print <<EOF;

 Usage: $0 <action> arg1=value arg2=value ...
 Example: $0 test verbose=1
 
 Actions defined:
  build                      clean
  test                       realclean
  dist                       install
  help                       fakeinstall

EOF
}

sub ACTION_test {
  my ($self) = @_;
  require Test::Harness;
  
  $self->depends_on('build');
  
  $Test::Harness::verbose = $self->{args}{verbose} || 0;
  local $ENV{TEST_VERBOSE} = $self->{args}{verbose} || 0;
  local @INC = (File::Spec->catdir('blib','lib'), @INC);
  
  if (-e 'test.pl') {
    Test::Harness::runtests('test.pl');
  } elsif (-e 't' and -d _) {
    my $tests = $self->rscan_dir('t', qr{\.t$});
    Test::Harness::runtests(@$tests);
  } else {
    print "No tests defined.\n";
  }
}

sub ACTION_build {
  my ($self) = @_;
  
  # What more needs to be done when creating blib/ from lib/?
  # Currently we handle .pm, .xs, and .pod files, we don't handle .PL stuff.
  my $files = $self->rscan_dir('lib', qr{\.(pm|pod|xs)$});
  $self->lib_to_blib($files, 'blib');
  $self->add_to_cleanup('blib');
}

sub ACTION_install {
  my ($self) = @_;
  require ExtUtils::Install;  # Grr, uses MakeMaker
  $self->depends_on('build');
  ExtUtils::Install::install($self->install_map, 1, 0);
}

sub ACTION_fakeinstall {
  my ($self) = @_;
  require ExtUtils::Install;  # Grr, uses MakeMaker
  $self->depends_on('build');
  ExtUtils::Install::install($self->install_map, 1, 1);
}

sub ACTION_clean {
  my ($self) = @_;
  foreach my $item (keys %{$self->{cleanup}}, keys %{$self->{new_cleanup}}) {
    $self->delete_filetree($item);
  }
}

sub ACTION_realclean {
  my ($self) = @_;
  $self->depends_on('clean');
  $self->delete_filetree($self->{config_dir}, $self->{build_script});
}

sub ACTION_dist {
  my ($self) = @_;
  (my $dist_dir = $self->{args}{module_name}) =~ s/::/-/;
  $dist_dir .= "-$self->{args}{module_version}";
  mkdir $dist_dir or die "Can't create '$dist_dir/': $!";
  
  require ExtUtils::Manifest;
  my $dist_files = ExtUtils::Manifest::maniread('MANIFEST');
  ExtUtils::Manifest::manicopy($dist_files, $dist_dir, 'best');
  
  $self->make_tarball($dist_dir);
  $self->delete_filetree($dist_dir);
}

sub make_tarball {
  my ($self, $dir) = @_;
  
  require Archive::Tar;
  my $files = $self->rscan_dir($dir);
  print "Creating $dir.tar.gz\n";
  Archive::Tar->create_archive("$dir.tar.gz", 1, @$files);
}

sub install_map {
  my $self = shift;
  my $blib = File::Spec->catfile('blib','lib');
  return {$blib => $self->{args}{sitelib},
	  read  => ''};  # To keep ExtUtils::Install quiet
}

sub depends_on {
  my $self = shift;
  foreach my $action (@_) {
    my $method = "ACTION_$action";
    $self->$method;
  }
}

sub rscan_dir {
  my ($self, $dir, $pattern) = @_;
  my @result;
  my $subr = $pattern ? sub {push @result, $File::Find::name if /$pattern/}
                      : sub {push @result, $File::Find::name};
  File::Find::find({wanted => $subr, no_chdir => 1}, $dir);
  return \@result;
}

sub delete_filetree {
  my $self = shift;
  foreach (@_) {
    next unless -e $_;
    print "Deleting $_\n";
    if (-d $_) {
      File::Path::rmtree($_, 0, 1);
    } else {
      unlink $_;
    }
    die "Couldn't remove '$_': $!\n" if -e $_;
  }
}

sub lib_to_blib {
  my ($self, $files, $to) = @_;
  
  foreach my $file (@$files) {
    if ($file =~ /\.p(m|od)$/) {
      # No processing needed
      $self->copy_if_modified($file, $to);

    } elsif ($file =~ /\.xs$/) {
      $self->process_xs($file);

    } elsif ($file =~ /\.PL$/) {
      # XXX Run the script

    } else {
      warn "Ignoring file '$file', unknown extension\n";
    }
  }
}


# A lot of this looks Unixy, but actually it may work fine on Windows.
# I'll see what people tell me about their results.
sub process_xs {
  my ($self, $file) = @_;
  my $args = $self->{args}; # For convenience

  # File name, minus the suffix
  (my $file_base = $file) =~ s/\.[^.]+$//;

  # .xs -> .c
  if ($self->is_newer_than($file, "$file_base.c")) {
    $self->add_to_cleanup("$file_base.c");
    
    my $xsubpp  = $self->module_name_to_file('ExtUtils::xsubpp')
      or die "Can't find ExtUtils::xsubpp in INC (@INC)";
    my $typemap =  $self->module_name_to_file('ExtUtils::typemap');
    
    $self->do_system("$args->{perl5} -I$args->{archlib} -I$args->{privlib} $xsubpp" .
		     " -noprototypes -typemap '$typemap' $file > $file_base.c")
      or die "error building .c file from '$file'";
  }
  
  # .c -> .o
  if ($self->is_newer_than("$file_base.c", "$file_base$args->{obj_ext}")) {
    $self->add_to_cleanup("$file_base$args->{obj_ext}");
    my $coredir = File::Spec->catdir($args->{archlib}, 'CORE');
    $self->do_system("$args->{cc} -c -o $file_base$args->{obj_ext} $args->{ccflags} -I$coredir $file_base.c")
      or die "error building $args->{dlext} file from '$file_base.c'";
  }
  
  # .xs -> .bs
  if ($self->is_newer_than($file, "$file_base.bs")) {
    $self->add_to_cleanup("$file_base.bs");
    require ExtUtils::Mkbootstrap;
    print "ExtUtils::Mkbootstrap::Mkbootstrap('$file_base')\n";
    ExtUtils::Mkbootstrap::Mkbootstrap($file_base);  # Original had $BSLOADLIBS - what's that?
    {open my $fh, ">> $file_base.bs"}  # touch
  }
  $self->copy_if_modified("$file_base.bs", 'blib');
  
  # .o -> .(a|bundle)
  my $lib_file = File::Spec->catfile('blib', "$file_base.$args->{dlext}");
  if ($self->is_newer_than("$file_base$args->{obj_ext}", $lib_file)) {
    $self->do_system("$args->{shrpenv} $args->{cc} -o $lib_file $args->{lddlflags} $file_base$args->{obj_ext}")
      or die "error building $args->{obj_ext} file from '$file_base.$args->{dlext}'";
  }
}

sub do_system {
  my ($self, $cmd, $silent) = @_;
  print "$cmd\n" unless $silent;
  return !system($cmd);
}

sub copy_if_modified {
  my ($self, $file, $to) = @_;

  my $to_path = File::Spec->catfile($to, $file);
  if (!-e $to_path or -M $to_path > -M "$file") {
    # Create parent directories
    my $path = File::Basename::dirname($file);
    File::Path::mkpath(File::Spec->catfile($to, $path), 0, 0777);
    
    print "$file -> $to_path\n";
    File::Copy::copy($file, $to_path) or die "Can't copy('$file', '$to_path'): $!";
  }
}

sub is_newer_than {
  my ($self, $one, $two) = @_;
  return 1 unless -e $two;
  return -M $one < -M $two;
}

1;
__END__


=head1 NAME

Module::Build::Base - Default methods for Module::Build

=head1 SYNOPSIS

  please see the Module::Build documentation

=head1 DESCRIPTION

The C<Module::Build::Base> module defines the core functionality of
C<Module::Build>.  Its methods may be overridden by any of the
platform-independent modules in the C<Module::Build::Platform::>
namespace, but the intention here is to make this base module as
platform-neutral as possible.  Nicely enough, Perl has several core
tools available in the C<File::> namespace for doing this, so the task
isn't very difficult.

Please see the C<Module::Build> documentation for more details.

=head1 AUTHOR

Ken Williams, ken@forum.swarthmore.edu

=head1 SEE ALSO

perl(1), Module::Build(3)

=cut
