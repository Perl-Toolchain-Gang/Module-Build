package Module::Build::Base;

use strict;
use Config;
use File::Copy ();
use File::Find ();
use File::Path ();
use File::Basename ();
use Test::Harness ();

sub new {
  my ($package) = @_;
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
  $self->write_config;
  
  return $self;
}

sub resume {
  my $package = shift;
  my $self = bless {@_}, $package;
  
  $self->read_config;
  my ($action, $args) = $self->cull_args(@ARGV);
  $self->{action} = $action || 'build';
  $self->{args} = {%{$self->{args}}, %$args};
  return $self;
}

sub read_config {
  my ($self) = @_;
  
  open my $fh, "$self->{config_dir}/build_params" 
    or die "Can't create '$self->{config_dir}/build_params': $!";
  
  while (<$fh>) {
    $self->{args}{$1} = $2 if /^(\w+)=(.*)/;
  }
}

sub write_config {
  my ($self) = @_;
  
  $self->delete_filetree($self->{config_dir});
  mkdir $self->{config_dir}, 0777
    or die "Can't mkdir $self->{config_dir}: $!";
  
  open my $fh, ">$self->{config_dir}/build_params" 
    or die "Can't create '$self->{config_dir}/build_params': $!";
  
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
  my $build_dir = File::Basename::dirname($0);
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

EOF
}

sub create_build_script {
  my ($self) = @_;
  
  $self->check_manifest;
  
  $self->rm_previous_build_script;

  print "Creating new '$self->{build_script}' file\n";
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
  
  # Depends on 'build'
  $self->ACTION_build;
  
  $Test::Harness::verbose = $self->{args}{verbose} || 0;
  
  if (-e 'test.pl') {
    # XXX Is this right?
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
}

sub ACTION_clean {
  my ($self) = @_;
  # This stuff shouldn't be hard-coded here, it'll come from a data file of saved state info
  $self->delete_filetree('blib');
}

sub ACTION_realclean {
  my ($self) = @_;
  $self->ACTION_clean;
  $self->delete_filetree($self->{config_dir}, $self->{build_script});
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
    if (!-e "$to/$file" or -M "$to/$file" > -M "$file") {
      # Create parent directories
      my $path = File::Basename::dirname($file);
      File::Path::mkpath("$to/$path", 0, 0777);
      
      print "$file -> $to/$file\n";
      File::Copy::copy($file, "$to/$file") or die "Can't copy('$file', '$to/$file'): $!";
    }
  }
}

1;
__END__


=head1 NAME

Module::Build - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Module::Build;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Module::Build, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.


=head1 AUTHOR

Ken Williams, ken@forum.swarthmore.edu

=head1 SEE ALSO

perl(1), ExtUtils::MakeMaker(3)

=cut
