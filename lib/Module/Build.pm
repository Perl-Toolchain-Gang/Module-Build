package Module::Build;

# This module doesn't do much of anything itself, it inherits from the
# modules that do the real work.  The only real thing it has to do is
# figure out which OS-specific module to pull in.  Many of the
# OS-specific modules don't do anything either - most of the work is
# done in Module::Build::Base.

use strict;
use File::Spec ();
use File::Path ();
use File::Basename ();

use vars qw($VERSION @ISA);
$VERSION = '0.14';

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

This is a beta version of a new module I've been working on,
C<Module::Build>.  It is meant to be a replacement for
C<ExtUtils::MakeMaker>.

To install C<Module::Build>, and any other module that uses
C<Module::Build> for its installation process, do the following:

  perl Build.PL       # 'Build.PL' script creates the 'Build' script
  ./Build             # Need ./ to ensure we're using this "Build" script
  ./Build test        # and not another one that happens to be in the PATH
  ./Build install

This illustrates initial configuration and the running of three
'actions'.  In this case the actions run are 'build' (the default
action), 'test', and 'install'.  Actions defined so far include:

  build                          fakeinstall 
  clean                          help        
  diff                           install     
  dist                           manifest    
  distcheck                      realclean   
  distclean                      skipcheck   
  distdir                        test        
  disttest                       testdb      

You can run the 'help' action for a complete list of actions.

When creating a C<Build.PL> script for a module, something like the
following code will typically be used:

  use Module::Build;
  my $build = new Module::Build
    (
     module_name => 'Foo::Bar',
     license => 'perl',
     requires => {
                  perl           => '5.6.1',
                  Some::Module   => '1.23',
                  Other::Module  => '>= 1.2, != 1.5, < 2.0',
                 },
    );
  $build->create_build_script;

A simple module could get away with something as short as this for its
C<Build.PL> script:

  use Module::Build;
  Module::Build->new(
     module_name => 'Foo::Bar',
     license => 'perl',
  )->create_build_script;

The model used by C<Module::Build> is a lot like the C<MakeMaker>
metaphor, with the following correspondences:

   In ExtUtils::MakeMaker               In Module::Build
  ------------------------             ---------------------------
   Makefile.PL (initial script)         Build.PL (initial script)
   Makefile (a long Makefile)           Build (a short perl script)
   <none>                               _build/ (for saving state info)

Any customization can be done simply by subclassing C<Module::Build>
and adding a method called (for example) C<ACTION_test>, overriding
the default 'test' action.  You could also add a method called
C<ACTION_whatever>, and then you could perform the action C<Build
whatever>.

For information on providing backward compatibility with
C<ExtUtils::MakeMaker>, see L<Module::Build::Compat>.

=head1 METHODS

I list here some of the most important methods in C<Module::Build>.
Normally you won't need to deal with these methods unless you want to
subclass C<Module::Build>.  But since one of the reasons I created
this module in the first place was so that subclassing is possible
(and easy), I will certainly write more docs as the interface
stabilizes.

=over 4

=item new()

Creates a new Module::Build object.  Arguments to the new() method are
listed below.  Most arguments are optional, but you must provide
either the C<module_name> argument, or C<dist_name> and one of
C<dist_version> or C<dist_version_from>.  In other words, you must
provide enough information to determine both a distribution name and
version.

=over 4

=item module_name

The C<module_name> is a shortcut for setting default values of
C<dist_name> and C<dist_version_from>, reflecting the fact that the
majority of CPAN distributions are centered around one "main" module.
For instance, if you set C<module_name> to C<Foo::Bar>, then
C<dist_name> will default to C<Foo-Bar> and C<dist_version_from> will
default to C<lib/Foo/Bar.pm>.  C<dist_version_from> will in turn be
used to set C<dist_version>.

Setting C<module_name> won't override a C<dist_*> parameter you
specify explicitly.

=item dist_name

Specifies the name for this distribution.  Most authors won't need to
set this directly, they can use C<module_name> to set C<dist_name> to
a reasonable default.  However, some agglomerative distributions like
C<libwww-perl> or C<bioperl> have names that don't correspond directly
to a module name, so C<dist_name> can be set independently.

=item dist_version

Specifies a version number for the distribution.  See C<module_name>
or C<dist_version_from> for ways to have this set automatically from a
C<$VERSION> variable in a module.  One way or another, a version
number needs to be set.

=item dist_version_from

Specifies a file to look for the distribution version in.  Most
authors won't need to set this directly, they can use C<module_name>
to set it to a reasonable default.

The version is extracted from the specified file according to the same
rules as C<ExtUtils::MakeMaker> and C<CPAN.pm>.  It involves finding
the first line that matches the regular expression

   /([\$*])(([\w\:\']*)\bVERSION)\b.*\=/

, eval()-ing that line, then checking the value of the C<$VERSION>
variable.  Quite ugly, really, but all the modules on CPAN depend on
this process, so there's no real opportunity to change to something
better.

=item license

Specifies the licensing terms of your distribution.  Valid options include:

=over 4

=item perl

The distribution may be copied and redistributed under the same terms
as perl itself (this is by far the most common licensing option for
modules on CPAN).  This is a dual license, in which the user may
choose between either the GPL or the Artistic license.

=item gpl

The distribution is distributed under the terms of the Gnu Public
License.

=item artistic

The distribution is licensed under the Artistic License, as specified
by the F<Artistic> file in the standard perl distribution.

=item restrictive

The distribution may not be redistributed without special arrangement
with the author.

=back

Note that you must still include the terms of your license in your
documentation - this field only lets automated tools figure out your
licensing restrictions.  Humans still need something to read.

It is a fatal error to use a license other than the ones mentioned
above.  This is not because I wish to impose licensing terms on you -
please let me know if you would like another license option to be
added to the list.  You may also use a license type of C<unknown> if
you don't wish to specify your terms (but this is usually not a good
idea for you to do!).

I just started out with a small set of licenses to keep things simple,
figuring I'd let people with actual working knowledge in this area
tell me what to do.  So if that's you, drop me a line.

=item requires

An optional C<requires> argument specifies any module prerequisites that
the current module depends on.  The prerequisites are given in a hash
reference, where the keys are the module names and the values are
version specifiers:

 requires => {Foo::Module => '2.4',
              Bar::Module => 0,
              Ken::Module => '>= 1.2, != 1.5, < 2.0',
              perl => '5.6.0'},

These four version specifiers have different effects.  The value
C<'2.4'> means that B<at least> version 2.4 of C<Foo::Module> must be
installed.  The value C<0> means that B<any> version of C<Bar::Module>
is acceptable, even if C<Bar::Module> doesn't define a version.  The
more verbose value C<'E<gt>= 1.2, != 1.5, E<lt> 2.0'> means that
C<Ken::Module>'s version must be B<at least> 1.2, B<less than> 2.0,
and B<not equal to> 1.5.  The list of criteria is separated by commas,
and all criteria must be satisfied.

A special C<perl> entry lets you specify the versions of the Perl
interpreter that are supported by your module.  The same version
dependency-checking semantics are available, except that we also
understand perl's new double-dotted version numbers.

One note: currently C<Module::Build> doesn't actually I<require> the
user to have dependencies installed, it just strongly urges.  In the
future we may require it.  There's now a C<recommends> section for
things that aren't absolutely required.

Automated tools like CPAN.pm should refuse to install a module if one
of its dependencies isn't satisfied, unless a "force" command is given
by the user.  If the tools are helpful, they should also offer to
install the dependencies.

A sysnonym for C<requires> is C<prereq>, to help succour people
transitioning from C<ExtUtils::MakeMaker>.  The C<requires> term is
preferred, but the C<prereq> term will remain valid in future
distributions.

=item recommends

This is just like the C<requires> argument, except that modules listed
in this section aren't essential, just a good idea.  We'll just print
a friendly warning if one of these modules aren't found, but we'll
continue running.

If a module is recommended but not required, all tests should still
pass if the module isn't installed.  This may mean that some tests
will be skipped if recommended dependencies aren't present.

Automated tools like CPAN.pm should inform the user when recommended
modules aren't installed, and it should offer to install them if it
wants to be helpful.

=item build_requires

Modules listed in this section are necessary to build and install the
given module, but are not necessary for regular usage of it.  This is
actually an important distinction - it allows for tighter control over
the body of installed modules, and facilitates correct dependency
checking on binary/packaged distributions of the module.

=item conflicts

Modules listed in this section conflict in some serious way with the
given module.  C<Module::Build> will refuse to install the given
module if

=item c_source

An optional C<c_source> argument specifies a directory which contains
C source files that the rest of the build may depend on.  Any C<.c>
files in the directory will be compiled to object files.  The
directory will be added to the search path during the compilation and
linking phases of any C or XS files.

=item autosplit

An optional C<autosplit> argument specifies a file which should be run
through the C<Autosplit::autosplit()> function.  In general I don't
consider this a great idea, and I may even go so far as to remove this
feature later.  Let me know if I shouldn't.

=item dynamic_config

A boolean flag indicating whether the F<Build.PL> file must be
executed, or whether this module can be built, tested and installed
solely from consulting its metadata file.  The default value is 0,
reflecting the fact that "most" of the modules on CPAN just need to be
copied from one place to another.  The main reason to set this to a
true value is that your module performs some dynamic configuration as
part of its build/install process.

Currently C<Module::Build> doesn't actually do anything with this flag
- it's probably going to be up to tools like C<CPAN.pm> to do
something useful with it.  It can potentially bring lots of security,
packaging, and convenience improvements.

=back

=item create_build_script()

Creates an executable script called C<Build> in the current directory
that will be used to execute further user actions.  This script is
roughly analogous (in function, not in form) to the Makefile created
by C<ExtUtils::MakeMaker>.  This method also creates some temporary
data in a directory called C<_build/>.  Both of these will be removed
when the C<realclean> action is performed.

=item add_to_cleanup()

A C<Module::Build> method may call C<< $self->add_to_cleanup(@files) >>
to tell C<Module::Build> that certain files should be removed when the
user performs the C<Build clean> action.  I decided to make this a
dynamic method, rather than a static list of files, because these
static lists can get difficult to manage.  I preferred to keep the
responsibility for registering temporary files close to the code that
creates them.

=item resume()

You'll probably never call this method directly, it's only called from
the auto-generated C<Build> script.  The C<new()> method is only
called once, when the user runs C<perl Build.PL>.  Thereafter, when
the user runs C<Build test> or another action, the C<Module::Build>
object is created using the C<resume()> method.

=item dispatch()

This method is also called from the auto-generated C<Build> script.
It parses the command-line arguments into an action and an argument
list, then calls the appropriate routine to handle the action.
Currently (though this may change), an action C<foo> will invoke the
C<ACTION_foo> method.  All arguments (including everything mentioned
in L<ACTIONS> below) are contained in the C<< $self->{args} >> hash
reference.

=item os_type()

If you're subclassing Module::Build and some code needs to alter its
behavior based on the current platform, you may only need to know
whether you're running on Windows, Unix, MacOS, VMS, etc. and not the
fine-grained value of Perl's C<$^O> variable.  The C<os_type()> method
will return a string like C<Windows>, C<Unix>, C<MacOS>, C<VMS>, or
whatever is appropriate.  If you're running on an unknown platform, it
will return C<undef> - there shouldn't be many unknown platforms
though.

=item prereq_failures()

Returns a data structure containing information about any failed
prerequisites (of any of the types described above), or C<undef> if
all prerequisites are met.

The data structure returned is a hash reference.  The top level keys
are the type of prerequisite failed, one of "requires",
"build_requires", "conflicts", or "recommends".  The associated values
are hash references whose keys are the names of required (or
conflicting) modules.  The associated values of those are hash
references indicating some information about the failure.  For example:

 {
  have => '0.42',
  need => '0.59',
  message => 'Version 0.42 is installed, but we need version 0.59',
 }

or

 {
  have => '<none>',
  need => '0.59',
  message => 'Prerequisite Foo isn't installed',
 }

This hash has the same structure as the hash returned by the
C<check_installed_status()> method, except that in the case of
"conflicts" dependencies we change the "need" key to "conflicts" and
construct a proper message.

Examples:

  # Check a required dependency on Foo::Bar
  if ( $m->prereq_failures->{requires}{Foo::Bar} ) { ...

  # Check whether there were any failures
  if ( $m->prereq_failures ) { ...
  
  # Show messages for all failures
  my $failures = $m->prereq_failures;
  while (my ($type, $list) = each %$failures) {
    while (my ($name, $hash) = each %$list) {
      print "Failure for $name: $hash->{message}\n";
    }
  }

=item check_installed_status($module, $version)

This method returns a hash reference indicating whether a version
dependency on a certain module is satisfied.  The C<$module> argument
is given as a string like C<"Data::Dumper"> or C<"perl">, and the
C<$version> argument can take any of the forms described in L<requires>
above.  This allows very fine-grained version checking.

The returned hash reference has the following structure:

 {
  ok => $whether_the_dependency_is_satisfied,
  have => $version_already_installed,
  need => $version_requested, # Same as incoming $version argument
  message => $informative_error_message,
 }

If no version of C<$module> is currently installed, the C<have> value
will be the string C<< "<none>" >>.  Otherwise the C<have> value will
simply be the version of the installed module.  Note that this means
that if C<$module> is installed but doesn't define a version number,
the C<have> value will be C<undef> - this is why we don't use C<undef>
for the case when C<$module> isn't installed at all.


=item check_installed_version($module, $version)

Like C<check_installed_status()>, but simply returns true or false
depending on whether module C<$module> statisfies the dependency
C<$version>.

If the check succeeds, the return value is the actual version of
C<$module> installed on the system.  This allows you to do the
following:

 my $installed = $m->check_installed_version('DBI', '1.15');
 if ($installed) {
   print "Congratulations, version $installed of DBI is installed.\n";
 } else {
   die "Sorry, you must install DBI.\n";
 }

If the check fails, we return false and set C<$@> to an informative
error message.

If C<$version> is any nontrue value (notably zero) and any version of
C<$module> is installed, we return true.  In this case, if C<$module>
doesn't define a version, or if its version is zero, we return the
special value "0 but true", which is numerically zero, but logically
true.

In general you might prefer to use C<check_installed_status> if you
need detailed information, or this method if you just need a yes/no
answer.

=item prompt()

Asks the user a question and returns their response as a string.  The
first argument specifies the message to display to the user (for
example, C<"Where do you keep your money?">).  The second argument,
which is optional, specifies a default answer (for example,
C<"wallet">).  The user will be asked the question once.

If the current session doesn't seem to be interactive (i.e. if
C<STDIN> and C<STDOUT> look like they're attached to files or
something, not terminals), we'll just use the default without
letting the user provide an answer.

=item y_n()

Asks the user a yes/no question using C<prompt()> and returns true or
false accordingly.  The user will be asked the question repeatedly
until they give an answer that looks like "yes" or "no".

The first argument specifies the message to display to the user (for
example, C<"Shall I invest your money for you?">), and the second
argument specifies the default answer (for example, C<"y">).

Note that the default is specified as a string like C<"y"> or C<"n">,
and the return value is a Perl boolean value like 1 or 0.  I thought
about this for a while and this seemed like the most useful way to do
it.

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
C<Build test verbose=1>), in which case their values last only for the
lifetime of that command.  Per-action command-line parameters take
precedence over parameters specified at C<perl Build.PL> time.

The build process also relies heavily on the C<Config.pm> module, and
all the key=value pairs in C<Config.pm> are available in 

C<< $self->{config} >>.  If the user wishes to override any of the
values in C<Config.pm>, she may specify them like so:

  perl Build.PL config='siteperl=/foo perlpath=/wacky/stuff'

Not the greatest interface, I'm looking for alternatives.  Speak now!
Maybe:

  perl Build.PL config-siteperl=/foo config-perlpath=/wacky/stuff

or something.

The following build actions are provided by default.

=over 4

=item help

This action will simply print out a message that is meant to help you
use the build process.  It will show you a list of available build
actions too.

=item build

If you run the C<Build> script without any arguments, it runs the
C<build> action.

This is analogous to the MakeMaker 'make all' target.
By default it just creates a C<blib/> directory and copies any C<.pm>
and C<.pod> files from your C<lib/> directory into the C<blib/>
directory.  It also compiles any C<.xs> files from C<lib/> and places
them in C<blib/>.  Of course, you need a working C compiler
(probably the same one that built perl itself) for this to work
properly.

The C<build> action also runs any C<.PL> files in your F<lib/>
directory.  Typically these create other files, named the same but
without the C<.PL> ending.  For example, a file F<lib/Foo/Bar.pm.PL>
could create the file F<lib/Foo/Bar.pm>.  The C<.PL> files are
processed first, so any C<.pm> files (or other kinds that we deal
with) will get copied correctly.

If your C<.PL> scripts don't create any files, or if they create files
with unexpected names, or even if they create multiple files, you
should tell us that so that we can clean up properly after these
created files.  Use the C<PL_files> parameter to C<new()>:

 PL_files => { 'lib/Foo/Bar_pm.PL' => 'lib/Foo/Bar.pm',
               'lib/something.PL'  => ['/lib/something', '/lib/else'],
               'lib/funny.PL'      => [] }

Note that in contrast to MakeMaker, the C<build> action only
(currently) handles C<.pm>, C<.pod>, C<.PL>, and C<.xs> files.  They
must all be in the C<lib/> directory, in the directory structure that
they should have when installed.  We also handle C<.c> files that can
be in the place of your choosing - see the C<c_source> argument to
C<new()>.

The C<.xs> support is currently in alpha.  Please let me know whether
it works for you.

=item test

This will use C<Test::Harness> to run any regression tests and report
their results.  Tests can be defined in the standard places: a file
called C<test.pl> in the top-level directory, or several files ending
with C<.t> in a C<t/> directory.

If you want tests to be 'verbose', i.e. show details of test execution
rather than just summary information, pass the argument C<verbose=1>.

If you want to run tests under the perl debugger, pass the argument
C<debugger=1>.

In addition, if a file called C<visual.pl> exists in the top-level
directory, this file will be executed as a Perl script and its output
will be shown to the user.  This is a good place to put speed tests or
other tests that don't use the C<Test::Harness> format for output.

To override the choice of tests to run, you may pass a C<test_files>
argument whose value is a whitespace-separated list of test scripts to
run.  This is especially useful in development, when you only want to
run a single test to see whether you've squashed a certain bug yet:

 ./Build test verbose=1 test_files=t/something_failing.t

=item testdb

This is a synonym for the 'test' action with the C<debugger=1>
argument.

=item clean

This action will clean up any files that the build process may have
created, including the C<blib/> directory (but not including the
C<_build/> directory and the C<Build> script itself).

=item realclean

This action is just like the C<clean> action, but also removes the
C<_build> directory and the C<Build> script.  If you run the
C<realclean> action, you are essentially starting over, so you will
have to re-create the C<Build> script again.

=item diff

This action will compare the files about to be installed with their
installed counterparts.  For .pm and .pod files, a diff will be shown
(this currently requires a 'diff' program to be in your PATH).  For
other files like compiled binary files, we simply report whether they
differ.

A C<flags> parameter may be passed to the action, which will be passed
to the 'diff' program.  Consult your 'diff' documentation for the
parameters it will accept - a good one is C<-u>:

 ./Build diff flags=-u

=item install

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

=item fakeinstall

This is just like the C<install> action, but it won't actually do
anything, it will just report what it I<would> have done if you had
actually run the C<install> action.

=item manifest

This is an action intended for use by module authors, not people
installing modules.  It will bring the F<MANIFEST> up to date with the
files currently present in the distribution.  You may use a
F<MANIFEST.SKIP> file to exclude certain files or directories from
inclusion in the F<MANIFEST>.  F<MANIFEST.SKIP> should contain a bunch
of regular expressions, one per line.  If a file in the distribution
directory matches any of the regular expressions, it won't be included
in the F<MANIFEST>.

The following is a reasonable F<MANIFEST.SKIP> starting point, you can
add your own stuff to it:

   ^_build
   ^Build$
   ^blib
   ~$
   \.bak$
   ^MANIFEST\.SKIP$
   CVS

See the L<distcheck> and L<skipcheck> actions if you want to find out
what the C<manifest> action would do, without actually doing anything.

=item dist

This action is helpful for module authors who want to package up their
module for distribution through a medium like CPAN.  It will create a
tarball of the files listed in F<MANIFEST> and compress the tarball using
GZIP compression.

=item distcheck

Reports which files are in the build directory but not in the
F<MANIFEST> file, and vice versa. (See L<manifest> for details)

=item skipcheck

Reports which files are skipped due to the entries in the
F<MANIFEST.SKIP> file (See L<manifest> for details)

=item distclean

Performs the 'realclean' action and then the 'distcheck' action.

=item distdir

Creates a directory called C<$(DISTNAME)-$(VERSION)> (if that
directory already exists, it will be removed first).  Then copies all
the files listed in the F<MANIFEST> file to that directory.  This
directory is what people will see when they download your distribution
and unpack it.

While performing the 'distdir' action, a file containing various bits
of "metadata" will be created.  The metadata includes the module's
name, version, dependencies, license, and the C<dynamic_config>
flag.  This file is created as F<META.yaml> in YAML format, so you
must have the C<YAML> module installed in order to create it.  You
should also ensure that the F<META.yaml> file is listed in your
F<MANIFEST> - if it's not, a warning will be issued.

=item disttest

Performs the 'distdir' action, then switches into that directory and
runs a C<perl Build.PL>, followed by the 'build' and 'test' actions in
that directory.

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

=head1 SUBCLASSING

Right now, there are two ways to subclass Module::Build.  The first
way is to create a regular module (in a C<.pm> file) that inherits
from Module::Build, and use that module's class instead of using
Module::Build directly:

  ------ in Build.PL: ----------
  #!/usr/bin/perl
  
  use lib qw(/nonstandard/library/path);
  use My::Builder;  # Or whatever you want to call it
  
  my $m = My::Builder->new(module_name => 'Next::Big::Thing');
  $m->create_build_script;

This is relatively straightforward, and is the best way to do things
if your My::Builder class contains lots of code.  The
C<create_build_script()> method will ensure that the current value of
C<@INC> (including the C</nonstandard/library/path>) is propogated to
the Build script, so that My::Builder can be found when running build
actions.

For very small additions, Module::Build provides a C<subclass()>
method that lets you subclass Module::Build more conveniently, without
creating a separate file for your module:

  ------ in Build.PL: ----------
  #!/usr/bin/perl
  
  my $class = Module::Build->subclass
    (
     class => 'My::Builder',
     code => q{
      sub ACTION_foo {
        print "I'm fooing to death!\n";
      }
     },
    );
  
  my $m = $class->new(module_name => 'Module::Build');
  $m->create_build_script;

Behind the scenes, this actually does create a C<.pm> file, since the
code you provide must persist after Build.PL is run if it is to be
very useful.


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
and installing software?  Even if that software is a bunch of stupid
little C<.pm> files that just need to be copied from one place to
another?  Are you getting riled up yet??

=back

Please contact me if you have any questions or ideas.

=head1 TO DO

The current method of relying on time stamps to determine whether a
derived file is out of date isn't likely to scale well, since it
requires tracing all dependencies backward, it runs into problems on
NFS, and it's just generally flimsy.  It would be better to use an MD5
signature or the like, if available.  See C<cons> for an example.

The current dependency-checking is prone to errors.  You
can make 'widowed' files by doing C<Build>, C<perl Build.PL>, and then
C<Build realclean>.  Should be easy to fix, but it's got me wondering
whether the dynamic declaration of dependencies is a good idea.

- make man pages and install them.
- append to perllocal.pod
- write .packlist in appropriate location (needed for un-install)

=head1 AUTHOR

Ken Williams, ken@mathforum.org

=head1 SEE ALSO

perl(1), ExtUtils::MakeMaker(3), YAML(3)

http://www.dsmit.com/cons/

=cut
