package Module::Build::Platform::Windows;

use strict;

use File::Basename;
use File::Spec;

use Module::Build::Base;

use vars qw(@ISA);
@ISA = qw(Module::Build::Base);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  my $cf = $self->{config};

  # Find 'pl2bat.bat' utility used for installing perl scripts.
  # This search is probably overkill, as I've never met a MSWin32 perl
  # where these locations differed from each other.
  my @potential_dirs = map { File::Spec->canonpath($_) }
    @${cf}{qw(installscript installbin installsitebin installvendorbin)},
    File::Basename::dirname($self->{properties}{perl});

  foreach my $dir (@potential_dirs) {
    my $potential_file = File::Spec->catfile($dir, 'pl2bat.bat');
    if ( -f $potential_file && !-d _ ) {
      $cf->{pl2bat} = $potential_file;
      last;
    }
  }

  return $self;
}

sub make_executable {
  my $self = shift;
  $self->SUPER::make_executable(@_);

  my $pl2bat = $self->{config}{pl2bat};

  if ( defined($pl2bat) && length($pl2bat) ) {
    foreach my $script (@_) {
      # Don't run 'pl2bat.bat' for the 'Build' script;
      # there is no easy way to get the resulting 'Build.bat'
      # to delete itself when doing a 'Build realclean'.
      next if ( $script eq $self->{properties}{build_script} );

      (my $script_bat = $script) =~ s/\.plx?//i;
      $script_bat .= '.bat' unless $script_bat =~ /\.bat$/i;

      my $status = $self->do_system($pl2bat, '<', $script, '>', $script_bat);
      if ( $status && -f $script_bat ) {
        $self->SUPER::make_executable($script_bat);
      } else {
        warn "Unable to convert '$script' to an executable.\n";
      }
    }
  } else {
    warn "Could not find 'pl2bat.bat' utility needed to make scripts executable.\n"
       . "Unable to convert scripts ( " . join(', ', @_) . " ) to executables.\n";
  }
}


sub manpage_separator {
    return '.';
}

sub split_like_shell {
  # In Win32 command shells, the backslashes in the string "\bar\baz"
  # should be preserved, because they often show up as parts of
  # pathnames.  We double-up all these backslashes so shellwords() can
  # still be used (making sure to avoid backslash-quote pairs, which
  # should work the same as on Unix)

  (my $self, local $_) = @_;
  if (defined() && length() && !ref()) {
    s/\\(?!")/\\\\/g;
  }

  return $self->SUPER::split_like_shell($_);
}

1;

__END__

=head1 NAME

Module::Build::Platform::Windows - Builder class for Windows platforms

=head1 DESCRIPTION

The sole purpose of this module is to inherit from
C<Module::Build::Base> and override a few methods.  Please see
L<Module::Build> for the docs.

=head1 AUTHOR

Ken Williams <ken@mathforum.org>

Most of the code here was written by Randy W. Sims <RandyS@ThePierianSpring.org>.

=head1 SEE ALSO

perl(1), Module::Build(3)

=cut
