package Module::Build;

# This module doesn't do much of anything itself, it inherits from the
# modules that do the real work.  The only real thing it has to do is
# figure out which OS-specific module to pull in.  Many of the
# OS-specific modules don't do anything either - most of the work is
# done in Module::Build::Base.

use strict;
use vars qw($VERSION @ISA);
$VERSION = '0.02';

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

   perl Build.PL
   ./Build             # this script created by 'perl Build.PL'
   ./Build test
   ./Build install

 Other actions:

   ./Build clean
   ./Build realclean

=head1 DESCRIPTION

This is a very alpha version of a new module set I've been working on,
C<Module::Build>.  It is meant to be a replacement for
C<ExtUtils::MakeMaker>.

To install C<Module::Build>, and any other module that uses
C<Module::Build> for its installation process, do the following:

   perl Build.PL
   ./Build
   ./Build test
   ./Build install

Other actions so far are:

   ./Build clean
   ./Build realclean
   ./Build fakeinstall
   ./Build dist

It's very much like the C<MakeMaker> metaphor, except that C<Build> is a
Perl script, not a Makefile.  State is stored in a directory called
C<_build/>.

Any customization can be done simply by subclassing C<Module::Build> and
adding a method called (for example) C<ACTION_test>, overriding the
default action.  You could also add a method called C<ACTION_whatever>,
and then you could perform the action C<./Build whatever>.

More actions will certainly be added to the core - it should be easy
to do everything that the MakeMaker process can do.  It's going to
take some time, though.  In the meantime, I may implement some
pass-through functionality so that unknown actions are passed to
MakeMaker.


=head1 MOTIVATIONS

There are several reasons I wanted to start over, and not just fix
what I didn't like about MakeMaker:

=over 4

=item *

I don't like the core idea of MakeMaker, namely that C<make> should be
involved in the build process, for these reasons:

=over 4

=item +

When a person is installing a Perl module, what can you assume about
their environment?  Can you assume they have C<make>?  No, but you can
assume they have some version of Perl.

=item +

When a person is writing a Perl module for intended distribution, can
you assume that they know how to build a Makefile, so they can
customize their build process?  No, but you can assume they know Perl,
and could customize that way.

=back

For years, these things have been a barrier to people getting the
build/install process to do what they want.

=item *

There are several architectural decisions in MakeMaker that make it
very difficult to customize its behavior.  For instance, when using
MakeMaker you do C<use MakeMaker>, but the object created in
C<WriteMakefile()> is actually blessed into a package name that's
created on the fly, so you can't simply subclass
C<ExtUtils::MakeMaker>.  There is a workaround C<MY> package that lets
you override certain MakeMaker methods, but only certain explicitly
predefined (by MakeMaker) methods can be overridden.  Also, the method
of customization is very crude: you have to modify a string containing
the Makefile text for the particular target.

=item *

It is risky to make major changes to MakeMaker, since it does so many
things, is so important, and generally works.  C<Module::Build> is an
entirely seperate package so that I can work on it all I want, without
worrying about backward compatibility.

=item *

Finally, Perl is said to be a language for system administration.
Could it really be the case that Perl isn't up to the task of building
and installing software?  Absolutely not - see the C<Cons> package for
one example, at L<http://www.dsmit.com/cons/> .

=back

Please contact me if you have any questions or ideas.


=head1 AUTHOR

Ken Williams, ken@forum.swarthmore.edu

=head1 SEE ALSO

perl(1), ExtUtils::MakeMaker(3)

http://www.dsmit.com/cons/

=cut
