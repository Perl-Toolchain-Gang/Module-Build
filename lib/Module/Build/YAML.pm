package Module::Build::YAML;
use strict;
use YAML::Tiny 1.40 ();
our @ISA = qw(YAML::Tiny);
our $VERSION  = '1.40';
1;

=head1 NAME

Module::Build::YAML - DEPRECATED

=head1 DESCRIPTION

This module was originally an inline copy of L<YAML::Tiny>.  It has been
deprecated in favor of using YAML::Tiny directly.  This module is kept as a
subclass wrapper for compatibility.

=cut

