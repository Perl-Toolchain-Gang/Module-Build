package Module::Build;

# This module doesn't do much of anything itself, it inherits from the
# modules that do the real work.  The only real thing it has to do is
# figure out which OS-specific module to pull in.  Many of the
# OS-specific modules don't do anything either - most of the work is
# done in Module::Build::Base.

use strict;
use vars qw($VERSION @ISA);
$VERSION = '0.03_2';

# Okay, this is the brute-force method of finding out what kind of
# platform we're on.  I don't know of a systematic way.  These values
# came from the latest (bleadperl) perlport.pod.

my %OSTYPES = qw(
		 aix       Unix
		 bsdos     Unix
		 dgux      Unix
		 dynixptx  Unix
		 freebsd   Unix
		 linux     Unix
		 hpux      Unix
		 irix      Unix
		 darwin    Unix
		 machten   Unix
		 next      Unix
		 openbsd   Unix
		 dec_osf   Unix
		 svr4      Unix
		 sco_sv    Unix
		 svr4      Unix
		 unicos    Unix
		 unicosmk  Unix
		 solaris   Unix
		 sunos     Unix
		 
		 dos       Windows
		 MSWin32   Windows
		 cygwin    Windows

		 os390     EBCDIC
		 os400     EBCDIC
		 posix-bc  EBCDIC
		 vmesa     EBCDIC

		 MacOS     MacOS
		 VMS       VMS
		 VOS       VOS
		 riscos    RiscOS
		 amigaos   Amiga
		 mpeix     MPEiX
		);

use File::Spec;

# We only use this once - don't waste a symbol table entry on it.
# More importantly, don't make it an inheritable method.
my $load = sub {
  my $mod = shift;
  #warn "Using $mod";
  eval "use $mod";
  die $@ if $@;
  @ISA = ($mod);
};

if (grep {-e File::Spec->catfile($_, qw(Module Build Platform), $^O) . '.pm'} @INC) {
  $load->("Module::Build::Platform::$^O");

} elsif (exists $OSTYPES{$^O}) {
  $load->("Module::Build::Platform::$OSTYPES{$^O}");

} else {
  warn "Unknown OS type '$^O' - using default settings\n";
  $load->("Module::Build::Platform::Default");
}

sub os_type { $OSTYPES{$^O} }

1;
__END__


=head1 NAME

Module::Build - Build and install Perl modules

=head1 SYNOPSIS

 Standard process for building & installing modules:
 
   perl Build.PL
   ./Build
   ./Build test
   ./Build install

=head1 DESCRIPTION

This is a beta version of a new module set I've been working on,
C<Module::Build>.  It is meant to be a replacement for
C<ExtUtils::MakeMaker>.

To install C<Module::Build>, and any other module that uses
C<Module::Build> for its installation process, do the following:

   perl Build.PL
   ./Build             # this script is created by 'perl Build.PL'
   ./Build test
   ./Build install

Other actions so far include:

   ./Build clean
   ./Build realclean
   ./Build fakeinstall
   ./Build dist
   ./Build help

It's like the C<MakeMaker> metaphor, except that C<Build> is a short
Perl script, not a long Makefile.  State is stored in a directory called
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

=head1 METHODS

I list here some of the most important methods in the
C<Module::Build>.  As the interface is still very unstable, I must ask
that for now, you read the source to get more information on them.
Normally you won't need to deal with these methods unless you want to
subclass C<Module::Build>.  But since one of the reasons I created
this module in the first place was so that subclassing is possible
(and easy), I will certainly write more docs as the interface
stabilizes.

=over 4

=item * Module::Build->new(...)

Creates a new Module::Build object.  The C<module_name> argument is
required, and should be a string like C<'Your::Module'>.  The
C<module_version> argument is optional - if not explicitly provided,
we'll look for the version string in the module specified by
C<module_name>, parsing it out according to the same rules as
C<ExtUtils::MakeMaker> and C<CPAN.pm>.

=item * add_to_cleanup

A C<Module::Build> method may call C<< $self->add_to_cleanup(@files) >>
to tell C<Module::Build> that certain files should be removed when the
user performs the C<Build clean> action.  I decided to make this a
dynamic method, rather than a static list of files, because these
static lists can get difficult to manage.  I preferred to keep the
responsibility for registering temporary files close to the code that
creates them.

=item * resume

You'll probably never call this method directly, it's only called from
the auto-generated C<Build> script.  The C<new()> method is only
called once, when the user runs C<perl Build.PL>.  Thereafter, when
the user runs C<Build test> or another action, the C<Module::Build>
object is created using the C<resume()> method.

=item * dispatch

This method is also called from the auto-generated C<Build> script.
It parses the command-line arguments into an action and an argument
list, then calls the appropriate routine to handle the action.
Currently (though this may change), an action C<foo> will invoke the
C<ACTION_foo> method.  All arguments (including everything mentioned
in L<ACTIONS> below) are contained in the C<< $self->{args} >> hash
reference.

=item * os_type

If you're subclassing Module::Build and some code needs to alter its
behavior based on the current platform, you may only need to know
whether you're running on Windows, Unix, MacOS, VMS, etc. and not the
fine-grained value of Perl's C<$^O> variable.  The C<os_type()> method
will return a string like C<Windows>, C<Unix>, C<MacOS>, C<VMS>, or
whatever is appropriate.  If you're running on an unknown platform, it
will return C<undef> - there shouldn't be many unknown platforms
though.

=back


=head1 ACTIONS

There are some general principles at work here.  First, each task when
building a module is called an "action".  These actions are listed
above; they correspond to the building, testing, installing,
packaging, etc. tasks.

Second, arguments are processed in a very systematic way.  Arguments
are always key=value pairs.  They may be specified at C<perl Build.PL>
time (i.e.  C<perl Build.PL sitelib=/my/secret/place>), in which case
their values last for the lifetime of the C<Build> script.  They may
also be specified when executing a particular action (i.e.
C<Build test verbose=1>, in which case their values last only for the
lifetime of that command.  The build process also relies heavily on
the C<Config.pm> module, and all the key=value pairs in C<Config.pm>
are merged into the mix too.  The precedence of parameters is, from
highest to lowest: per-action parameters, C<Build.PL> parameters, and
C<Config.pm> parameters.

The following build actions are provided by default.

=over 4

=item * build

This is analogous to the MakeMaker 'make' target with no arguments.
By default it just creates a C<blib/> directory and copies any C<.pm>
and C<.pod> files from your C<lib/> directory into the C<blib/>
directory.  It also compiles any C<.xs> files from C<lib/> and places
them in C<blib/>.  Of course, you need a working C compiler
(preferably the same one that built perl itself) for this to work
properly.

Note that in contrast to MakeMaker, this module only (currently)
handles C<.pm>, C<.pod>, and C<.xs> files.  They must all be in the
C<lib/> directory, in the directory structure that they should have
when installed.

If you run the C<Build> script without any arguments, it runs the
C<build> action.

In future releases of C<Module::Build> the C<build> action should be
able to process C<.PL> files.  The C<.xs> support is currently in
alpha.  Please let me know if it works for you.

=item * test

This will use C<Test::Harness> to run any regression tests and report
their results.  Tests can be defined in the standard places: a file
called C<test.pl> in the top-level directory, or several files ending
with C<.t> in a C<t/> directory.

If you want tests to be 'verbose', i.e. show details of test execution
rather than just summary information, pass the argument C<verbose=1>.

=item * clean

This action will clean up any files that the build process may have
created, including the C<blib/> directory (but not including the
C<_build/> directory and the C<Build> script itself).

=item * realclean

This action is just like the C<clean> action, but also removes the
C<_build> directory and the C<Build> script.  If you run the
C<realclean> action, you are essentially starting over, so you will
have to re-create the C<Build> script again.

=item * install

This action will use C<ExtUtils::Install> to install the files from
C<blib/> into the correct system-wide module directory.  The directory
is determined from the C<sitelib> entry in the C<Config.pm> module.
To install into a different directory, pass a different value for the
C<sitelib> parameter, like so:

 Build install sitelib=/my/secret/place/

Alternatively, you could specify the C<sitelib> parameter when you run
the C<Build.PL> script:

 perl Build.PL sitelib=/my/secret/place/

Under normal circumstances, you'll need superuser privileges to
install into the default C<sitelib> directory.

=item * fakeinstall

This is just like the C<install> action, but it won't actually do
anything, it will just report what it I<would> have done if you had
actually run the C<install> action.

=item * dist

This action is helpful for module authors who want to package up their
module for distribution through a medium like CPAN.  It will create a
tarball of the files listed in MANIFEST and compress the tarball using
GZIP compression.

=item * manifest

This is an action intended for use by module authors, not people
installing modules.  It will bring the MANIFEST up to date with the
files currently present in the distribution.  You may use a
MANIFEST.SKIP file to exclude certain files or directories from
inclusion in the MANIFEST.  MANIFEST.SKIP should contain a bunch of
regular expressions, one per line.  If a file in the distribution
directory matches any of the regular expressions, it won't be included
in the MANIFEST.

(Note to self: it would be nice to have a 'fake_manifest' action that
would just go through the motions of adding to MANIFEST but not
actually do anything.  Currently ExtUtils::Manifest doesn't support
it, though.)

=item * help

This action will simply print out a message that is meant to help you
use the build process.  It will show you a list of available build
actions too.

=back

=head1 AUTOMATION

One advantage of Module::Build is that since it's implemented as Perl
methods, you can invoke these methods directly if you want to install
a module non-interactively.  For instance, the following Perl script
will invoke the entire build/install procedure:

 my $m = new Module::Build (module_name => 'MyModule');
 $m->dispatch('build');
 $m->dispatch('test');
 $m->dispatch('install');

If any of these steps encounters an error, it will throw a fatal
exception.

You can also pass arguments as part of the build process:

 my $m = new Module::Build (module_name => 'MyModule');
 $m->dispatch('build');
 $m->dispatch('test', verbose => 1);
 $m->dispatch('install', sitelib => '/my/secret/place/');

Building and installing modules in this way skips creating the
C<Build> script.

=head1 STRUCTURE

Module::Build creates a class hierarchy conducive to customization.
Here is the parent-child class hierarchy in classy ASCII art:

   /--------------------\
   |   Your::Parent     |  (If you subclass Module::Build)
   \--------------------/
            |
            |
   /--------------------\  (Doesn't define any functionality
   |   Module::Build    |   of its own - just figures out what
   \--------------------/   other modules to load.)
            |
            |
   /-----------------------------------\  (Some values of $^O may
   |   Module::Build::Platform::$^O    |   define specialized functionality.
   \-----------------------------------/   Otherwise it's ...::Default, a
            |                              pass-through class.)
            |
   /--------------------------\
   |   Module::Build::Base    |  (Most of the functionality of 
   \--------------------------/   Module::Build is defined here.)


Right now, if you want to subclass Module::Build you must do so by
including an actual .pm file somewhere in your distribution.  There
will be much better ways to do this in the future.  Can't do
everything at once...


=head1 MOTIVATIONS

There are several reasons I wanted to start over, and not just fix
what I didn't like about MakeMaker:

=over 4

=item *

I don't like the core idea of MakeMaker, namely that C<make> should be
involved in the build process.  Here are my reasons:

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

=head1 TO DO

Need to implement a prerequisite mechanism, similar to MakeMaker's
C<PREREQ_PM> stuff.

There will also be a subclassing mechanism that doesn't require as
much module infrastructure to use.  Something like this:

 use Module::Build subclass => <<'EOF';
  sub ACTION_foo {
    ... implement the 'foo' action ...
  }
 EOF

The current method of relying on time stamps to determine whether a
derived file is out of date isn't likely to scale well, since it
requires tracing all dependencies backward, it runs into problems on
NFS, and it's just generally flimsy.  It would be better to use an MD5
signature or the like, if available.  See C<cons> for an example.

The current dependency-checking for .xs files is prone to errors.  You
can make 'widowed' files by doing C<Build>, C<perl Build.PL>, and then
C<Build realclean>.  Should be easy to fix, but it's got me wondering
whether the dynamic declaration of dependencies is a good idea.

=head1 AUTHOR

Ken Williams, ken@forum.swarthmore.edu

=head1 SEE ALSO

perl(1), ExtUtils::MakeMaker(3)

http://www.dsmit.com/cons/

=cut
