package Module::Build::Platform::aix;

use strict;
use Module::Build::Platform::Unix;

use vars qw(@ISA);
@ISA = qw(Module::Build::Platform::Unix);

sub need_prelink_c { 1 }

sub link_c {
  my ($self, $to, $file_base) = @_;
  my $cf = $self->{config};

  $file_base =~ tr/"//d; # remove any quotes
  my $perl_inc = File::Spec->catdir($cf->{archlibexp}, 'CORE'); #location of perl.exp

  # Massage some very naughty bits in %Config
  local $cf->{lddlflags} = $cf->{lddlflags};
  for ($cf->{lddlflags}) {
    s/\Q$(BASEEXT)\E/$file_base/;
    s/\Q$(PERL_INC)\E/$perl_inc/;
  }

  return $self->SUPER::link_c($to, $file_base);
}


1;
__END__


=head1 NAME

Module::Build::Platform::aix - Builder class for AIX platform

=head1 DESCRIPTION

This module provides some routines very specific to the AIX
platform.

Please see the L<Module::Build> for the general docs.

=head1 AUTHOR

Ken Williams, ken@mathforum.org

=head1 SEE ALSO

perl(1), Module::Build(3), ExtUtils::MakeMaker(3)

=cut
