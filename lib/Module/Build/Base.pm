package Module::Build::Base;

use strict;
use Config;
use File::Copy ();
use File::Find ();
use File::Path ();
use File::Basename ();
use File::Spec ();
use Test::Harness ();

sub new {
  my $package = shift;
  my $self = bless {
		    # Don't save these defaults in config_dir.
		    build_script => 'Build',
		    config_dir => '_build',
		    @_,
		   }, $package;
  
  my ($action, $args) = $self->cull_args(@ARGV);
  die "Too early to specify a build action '$action'.  Do ./$self->{build_script} $action instead.\n"
    if $action;

  $self->{args} = {%Config, @_, %$args};

  $self->find_version;
  $self->write_config;
  
  return $self;
}

sub resume {
  my $package = shift;
  my $self = bless {@_}, $package;
  
  $self->read_config;
  $self->{new_cleanup} = [];
  my ($action, $args) = $self->cull_args(@ARGV);
  $self->{action} = $action || 'build';
  $self->{args} = {%{$self->{args}}, %$args};
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
  my $file = File::Spec->catfile(split '::', $mod) . '.pm';
  foreach ('lib', @INC) {
    my $testfile = File::Spec->catfile($_, $file);
    return $testfile if -e $testfile;
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
  die "Couldn't find version string in '$self->{module_version_from}'";
}

sub add_to_cleanup {
  my $self = shift;
  push @{$self->{new_cleanup}}, @_;
}

sub write_cleanup {
  my ($self) = @_;
  return unless @{$self->{new_cleanup}};
  
  my $cleanup_file = File::Spec->catfile($self->{config_dir}, 'cleanup');
  open my $fh, ">$cleanup_file" or die "Can't write '$cleanup_file': $!";
  local $, = "\n";
  # Might not need to re-write the old stuff.
  print $fh @{$self->{cleanup}}, @{$self->{new_cleanup}};
}

sub config_file {
  my ($self) = @_;
  return File::Spec->catfile($self->{config_dir}, $_[1]);
}

sub read_config {
  my ($self) = @_;
  
  my $file = File::Spec->catfile($self->{config_dir}, 'build_params');
  open my $fh, $file or die "Can't read '$file': $!";
  
  while (<$fh>) {
    $self->{args}{$1} = $2 if /^(\w+)=(.*)/;
  }
  close $fh;
  
  my $cleanup_file = File::Spec->catfile($self->{config_dir}, 'cleanup');
  if (-e $cleanup_file) {
    open my $fh, $cleanup_file or die "Can't read '$file': $!";
    $self->{cleanup} = [<$fh>];
    chomp @{$self->{cleanup}};
  } else {
    $self->{cleanup} = [];
  }
}

sub write_config {
  my ($self) = @_;
  
  $self->delete_filetree($self->{config_dir});
  mkdir $self->{config_dir}, 0777
    or die "Can't mkdir $self->{config_dir}: $!";
  
  my $file = File::Spec->catfile($self->{config_dir}, 'build_params');
  open my $fh, ">$file" or die "Can't create '$file': $!";
  
  foreach my $key (sort(keys %Config), sort keys %{$self->{args}} ) {
    if ($self->{args}{$key} =~ /\n/) {
      warn "Sorry, can't handle newlines in config data '$key' (yet)\n";
      next;
    }
    print $fh "$key=$self->{args}{$key}\n";
  }
  close $fh;
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

chdir('$build_dir'); # Necessary?
use $build_package;

my \$build = resume $build_package (
  config_dir => '$self->{config_dir}',
  build_script => '$self->{build_script}',
);
\$build->dispatch;
\$build->write_cleanup;

EOF
}

sub create_build_script {
  my ($self) = @_;
  
  $self->check_manifest;
  
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

  my $action = "ACTION_$self->{action}";
  if ($self->can($action)) {
    print ref($self),"->$action\n";
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

sub ACTION_test {
  my ($self) = @_;
  
  $self->depends_on('build');
  
  $Test::Harness::verbose = $self->{args}{verbose} || 0;
  
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
  # Currently we only copy .pm files, we don't handle .xs or .PL stuff.
  my $files = $self->rscan_dir('lib', qr{\.pm$});
  $self->copy_if_modified($files, 'blib');
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
  foreach my $item (@{$self->{cleanup}}) {
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
  
  # Cross-platform snafu here - delay fix until later
  system($self->{args}{tar} || 'tar', 'cvf', "$dist_dir.tar", $dist_dir);
  $self->delete_filetree($dist_dir);
  system($self->{args}{gzip} || 'gzip', "$dist_dir.tar");
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
  my $subr = sub {push @result, $File::Find::name if /$pattern/};
  File::Find::find({wanted => $subr, no_chdir => 1}, $dir);
  return \@result;
}

sub delete_filetree {
  my $self = shift;
  require File::Path;
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

sub copy_if_modified {
  my ($self, $files, $to) = @_;
  
  foreach my $file (@$files) {
    my $to_path = File::Spec->catfile($to, $file);
    if (!-e $to_path or -M $to_path > -M "$file") {
      # Create parent directories
      my $path = File::Basename::dirname($file);
      File::Path::mkpath(File::Spec->catfile($to, $path), 0, 0777);
      
      print "$file -> $to_path\n";
      File::Copy::copy($file, $to_path) or die "Can't copy('$file', '$to_path'): $!";
    }
  }
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
