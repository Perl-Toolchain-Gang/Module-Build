package Module::Build::Platform::cygwin;

use strict;
use Module::Build::Platform::Unix;

use vars qw(@ISA);
@ISA = qw(Module::Build::Platform::Unix);

sub link_c {
  my ($self, $to, $file_base) = @_;
  my ($cf, $p) = ($self->{config}, $self->{properties}); # For convenience
  my $flags = $p->{extra_linker_flags};
  local $p->{extra_linker_flags} = ['-L'.File::Spec->catdir($cf->{archlibexp}, 'CORE'),
				    '-lperl',
				    ref $flags ? @$flags : $self->split_like_shell($flags)];
  return $self->SUPER::link_c($to, $file_base);
}

sub manpage_separator {
   '.'
}

1;
__END__


=head1 NAME

Module::Build::Platform::cygwin - Builder class for Cygwin platform

=head1 DESCRIPTION

This module provides some routines very specific to the cygwin
platform.

Please see the L<Module::Build> for the general docs.

=head1 AUTHOR

Initial stub by Yitzchak Scott-Thoennes, sthoenna@efn.org

=head1 SEE ALSO

perl(1), Module::Build(3), ExtUtils::MakeMaker(3)

=cut
