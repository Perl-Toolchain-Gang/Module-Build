package Module::Build::Platform::MacOS;

use strict;
use Module::Build::Base;

use vars qw(@ISA);
@ISA = qw(Module::Build::Base);


sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  
  $self->{config}{sitelib}  ||= $self->{config}{installsitelib};
  $self->{config}{sitearch} ||= $self->{config}{installsitearch};

  return $self;
}

sub make_build_script_executable {
  my $self = shift;
	
  # Can't hurt to make it read-only.
  $self->SUPER::make_build_script_executable;
	
  require MacPerl;
  MacPerl::SetFileInfo('McPL', 'TEXT', $self->{properties}{build_script});
}

sub rm_previous_build_script {
  my $self = shift;
    
  if( $self->{properties}{build_script} ) {
    chmod 666, $self->{properties}{build_script};
  }
  $self->SUPER::rm_previous_build_script;
}

sub dispatch {
  my $self = shift;

  if( !@_ and !@ARGV ) {
    require MacPerl;
      
    # What comes first in the action list.
    my @action_list = qw(test install build);
    my %actions;
    {
      no strict 'refs';
    
      foreach my $class ($self->super_classes) {
        foreach ( keys %{ $class . '::' } ) {
          $actions{$1}++ if /ACTION_(\w+)/;
        }
      }
    }
  
    delete @actions{@action_list};
    push @action_list, sort { $a cmp $b } keys %actions;
    $ARGV[0] = MacPerl::Pick('What build command?', @action_list);
    push @ARGV, split /\s+/, 
                  MacPerl::Ask('Any extra arguments?  (ie. verbose=1)', '');
  }
  
  $self->SUPER::dispatch(@_);
}

sub ACTION_realclean {
  my $self = shift;
  chmod 666, $self->{properties}{build_script};
  $self->SUPER::ACTION_realclean;
}

1;
__END__

=head1 NAME

Module::Build::Platform::MacOS - Builder class for MacOS platforms

=head1 DESCRIPTION

The sole purpose of this module is to inherit from
C<Module::Build::Base> and override a few methods.  Please see
L<Module::Build> for the docs.

=head2 Overriden Methods

=over 4

=item new()

MacPerl doesn't define $Config{sitelib} or $Config{sitearch} for some
reason, but $Config{installsitelib} and $Config{installsitearch} are
there.  So we copy the install variables to the other location

=item make_build_script_executable()

On MacOS we set the file type and creator to MacPerl so it will run
with a double-click.

=item rm_previous_build_script()

MacOS maps chmod -w to locking the file.  This mean we have to unlock
it before removing it.

=item dispatch()

Because there's no easy way to say "./Build test" on MacOS, if
dispatch is called with no arguments and no @ARGV a dialog box will
pop up asking what action to take and any extra arguments.

Default action is "test".

=item ACTION_realclean()

Need to unlock the Build program before deleting.

=back

=head1 AUTHOR

Michael G Schwern <schwern@pobox.com>

=head1 SEE ALSO

perl(1), Module::Build(3), ExtUtils::MakeMaker(3)

=cut
