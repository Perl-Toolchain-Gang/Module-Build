package Module::Build;

# This module doesn't do much of anything itself, it inherits from the
# modules that do the real work.  The only real thing it has to do is
# figure out which OS-specific module to pull in.  Many of the
# OS-specific modules don't do anything either - most of the work is
# done in Module::Build::Base.

use strict;
use vars qw($VERSION @ISA);
$VERSION = '0.01';

eval "use Module::Build::Platform::$^O";
if ($@) {
  #warn $@ unless $@ =~ /^Can't locate/;
  eval "use Module::Build::Platform::Default";
  die $@ if $@;
  @ISA = qw(Module::Build::Platform::Default);
} else {
  @ISA = ("Module::Build::Platform::$^O");
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

http://www.dsmit.com/cons/stable/cons.html

=cut
