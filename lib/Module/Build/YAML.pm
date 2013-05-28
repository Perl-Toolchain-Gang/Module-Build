package Module::Build::YAML;

use if $] >= 5.019, 'deprecate';

use strict;
use if $] > 5.018, 'deprecate';
use CPAN::Meta::YAML 0.002 ();
our @ISA = qw(CPAN::Meta::YAML);
our $VERSION  = '1.41';
1;

=head1 NAME

Module::Build::YAML - DEPRECATED

=head1 DESCRIPTION

This module was originally an inline copy of L<YAML::Tiny>.  It has been
deprecated in favor of using L<CPAN::Meta::YAML> directly.  This module is kept
as a subclass wrapper for compatibility.

=cut

