package Module::Build::Platform::Windows;

use strict;

use File::Basename;
use File::Spec;
use IO::File;

use Module::Build::Base;

use vars qw(@ISA);
@ISA = qw(Module::Build::Base);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);

  $self->_find_pl2bat();
  return $self;
}


sub _find_pl2bat {
  my $self = shift;
  my $cf = $self->{config};

  # Find 'pl2bat.bat' utility used for installing perl scripts.
  # This search is probably overkill, as I've never met a MSWin32 perl
  # where these locations differed from each other.

  my @potential_dirs;

  if ( $ENV{PERL_CORE} ) {

    require ExtUtils::CBuilder;
    @potential_dirs = File::Spec->catdir( ExtUtils::CBuilder->new()->perl_src(),
                                          qw/win32 bin/ );
  } else {
    @potential_dirs = map { File::Spec->canonpath($_) }
      @${cf}{qw(installscript installbin installsitebin installvendorbin)},
      File::Basename::dirname($self->perl);
  }

  foreach my $dir (@potential_dirs) {
    my $potential_file = File::Spec->catfile($dir, 'pl2bat.bat');
    if ( -f $potential_file && !-d _ ) {
      $cf->{pl2bat} = $potential_file;
      last;
    }
  }
}

sub make_executable {
  my $self = shift;
  $self->SUPER::make_executable(@_);

  my $perl = $self->perl;

  my $pl2bat = $self->{config}{pl2bat};
  my $pl2bat_args = '';

  if ( defined($pl2bat) && length($pl2bat) ) {

    foreach my $script (@_) {
      next if $script =~ /\.(bat|cmd)$/i; # already a script; nothing to do

      (my $script_bat = $script) =~ s/\.plx?$//i;
      $script_bat .= '.bat'; # MSWin32 executable batch script file extension

      my $quiet_state = $self->{properties}{quiet}; # keep quiet
      if ( $script eq $self->build_script ) {
        $self->{properties}{quiet} = 1;
        $pl2bat_args =
          q(-n "-x -S """%0""" "--build_bat" %*" ) .
          q(-o "-x -S """%0""" "--build_bat" %1 %2 %3 %4 %5 %6 %7 %8 %9");
      }

      my $status = $self->do_system("$perl $pl2bat $pl2bat_args " .
                                    "< $script > $script_bat");
      $self->SUPER::make_executable($script_bat);

      $self->{properties}{quiet} = $quiet_state; # restore quiet
    }

  } else {
    warn <<"EOF";
Could not find 'pl2bat.bat' utility needed to make scripts executable.
Unable to convert scripts ( @{[join(', ', @_)]} ) to executables.
EOF
  }
}

sub ACTION_realclean {
  my ($self) = @_;

  $self->SUPER::ACTION_realclean();

  my $basename = basename($0);
  $basename =~ s/(?:\.bat)?$//i;

  if ( $basename eq $self->build_script ) {
    if ( $self->build_bat ) {
      my $full_progname = $0;
      $full_progname =~ s/(?:\.bat)?$/.bat/i;

      # Syntax differs between 9x & NT: the later requires a null arg (???)
      require Win32;
      my $null_arg = (Win32::GetOSVersion == 2) ? '""' : '';
      my $cmd = qq(start $null_arg /min "\%comspec\%" /c del "$full_progname");

      my $fh = IO::File->new(">> $basename.bat")
        or die "Can't create $basename.bat: $!";
      print $fh $cmd;
      close $fh ;
    } else {
      $self->delete_filetree($self->build_script . '.bat');
    }
  }
}

sub manpage_separator {
    return '.';
}

sub split_like_shell {
  # As it turns out, Windows command-parsing is very different from
  # Unix command-parsing.  Double-quotes mean different things,
  # backslashes don't necessarily mean escapes, and so on.  So we
  # can't use Text::ParseWords::shellwords() to break a command string
  # into words.  The algorithm below was bashed out by Randy and Ken
  # (mostly Randy), and there are a lot of regression tests, so we
  # should feel free to adjust if desired.
  
  (my $self, local $_) = @_;
  
  return @$_ if defined() && UNIVERSAL::isa($_, 'ARRAY');
  
  my @argv;
  return @argv unless defined() && length();
  
  my $arg = '';
  my( $i, $quote_mode ) = ( 0, 0 );
  
  while ( $i < length() ) {
    
    my $ch      = substr( $_, $i  , 1 );
    my $next_ch = substr( $_, $i+1, 1 );
    
    if ( $ch eq '\\' && $next_ch eq '"' ) {
      $arg .= '"';
      $i++;
    } elsif ( $ch eq '\\' && $next_ch eq '\\' ) {
      $arg .= '\\';
      $i++;
    } elsif ( $ch eq '"' && $next_ch eq '"' && $quote_mode ) {
      $quote_mode = !$quote_mode;
      $arg .= '"';
      $i++;
    } elsif ( $ch eq '"' && $next_ch eq '"' && !$quote_mode &&
	      ( $i + 2 == length()  ||
		substr( $_, $i + 2, 1 ) eq ' ' )
	    ) { # for cases like: a"" => [ 'a' ]
      push( @argv, $arg );
      $arg = '';
      $i += 2;
    } elsif ( $ch eq '"' ) {
      $quote_mode = !$quote_mode;
    } elsif ( $ch eq ' ' && !$quote_mode ) {
      push( @argv, $arg ) if $arg;
      $arg = '';
      ++$i while substr( $_, $i + 1, 1 ) eq ' ';
    } else {
      $arg .= $ch;
    }
    
    $i++;
  }
  
  push( @argv, $arg ) if defined( $arg ) && length( $arg );
  return @argv;
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

Ken Williams <ken@cpan.org>, Randy W. Sims <RandyS@ThePierianSpring.org>

=head1 SEE ALSO

perl(1), Module::Build(3)

=cut
