package Module::Build::Cookbook;

=head1 NAME

Module::Build::Cookbook - Examples of Module::Build Usage

=head1 DESCRIPTION

C<Module::Build> isn't conceptually very complicated, but examples are
always helpful.  I got the idea for writing this cookbook when
attending Brian Ingerson's "Extreme Programming Tools for Module
Authors" presentation at YAPC 2003, when he said, straightforwardly,
"Write A Cookbook."

The definitional of how stuff works is in the main C<Module::Build>
documentation.  It's best to get familiar with that too.

=head1 BASIC RECIPES

=head2 The basic installation recipe for modules that use Module::Build

In most cases, you can just issue the following commands from your
shell:

 perl Build.PL
 Build
 Build test
 Build install

There's nothing complicated here - first you're running a script
called F<Build.PL>, then you're running a (newly-generated) script
called F<Build> and passing it various arguments.  If you know how to
do that on your system, you can get installation working.

The exact commands may vary a bit depending on how you invoke perl
scripts on your system.  For instance, if you have multiple versions
of perl installed, you can install to one particular perl's library
directories like so:

 /usr/bin/perl5.8.1 Build.PL
 Build
 Build test
 Build install

The F<Build> script knows what perl was used to run C<Build.PL>, so
you don't need to reinvoke the F<Build> script with the complete perl
path each time.  If you invoke it with the I<wrong> perl path, you'll
get a warning.

If the current directory (usually called '.') isn't in your path, you
can do C<./Build> or C<perl Build> to run the script:

 /usr/bin/perl Build.PL
 ./Build
 ./Build test
 ./Build install

=head2 Making a CPAN.pm-compatible distribution

New versions of CPAN.pm understand how to use a F<Build.PL> script,
but old versions don't.  If you want to help users who have old
versions, do the following:

Create a file in your distribution named F<Makefile.PL>, with the
following contents:  

 use Module::Build::Compat;
 Module::Build::Compat->run_build_pl(args => \@ARGV);
 Module::Build::Compat->write_makefile();

Now CPAN will work as usual, ie: `perl Makefile.PL`, `make`, `make test`,
and `make install`.

Alternatively, see the C<create_makefile_pl> parameter to the C<<
Module::Build->new() >> method.

=head2 Installing modules using the programmatic interface

If you need to build, test, and/or install modules from within some
other perl code (as opposed to having the user type installation
commands at the shell), you can use the programmatic interface.
Create a Module::Build object (or an object of a custom Module::Build
subclass) and then invoke its C<dispatch()> method to run various
actions.

 my $b = Module::Build->new(
   module_name => 'Foo::Bar',
   license => 'perl',
   requires => { 'Some::Module'   => '1.23' },
 );
 $b->dispatch('build');
 $b->dispatch('test', verbose => 1);
 $b->dispatch('install');

The first argument to C<dispatch()> is the name of the action, and any
following arguments are named parameters.

This is the interface we use to test Module::Build itself in the
regression tests.

=head2 Installing to a temporary directory

To create packages for package managers like RedHat's C<rpm> or
Debian's C<deb>, you may need to install to a temporary directory
first and then create the package from that temporary installation.
To do this, specify the C<destdir> parameter to the C<install> action:

 Build install destdir=/tmp/my-package-1.003

=head2 Running a single test file

C<Module::Builde> supports running a single test, which enables you to
track down errors more quickly. Use the following format:

  ./Build test --test_files t/mytest.t

In addition, you may want to run the test in verbose mode to get more
informative output:

  ./Build test --test_files t/mytest.t --verbose 1

I run this so frequently that I actually define the following shell alias:

  alias t './Build test --verbose 1 --test_files'

So then I can just execute C<t t/mytest.t> to run a single test.


=head1 ADVANCED RECIPES

=head2 Adding new elements to the build process

If there's some new type of file (i.e. not a F<.pm> file, or F<.xs>
file, or one of the other things C<Module::Build> knows how to
process) that you'd like to handle during the building of your module,
you can do something the following in your F<Build.PL> file:

  use Module::Build;
  
  my $class = Module::Build->subclass( code => <<'EOC' );
    sub process_foo_files {
      my $self = shift;
      ... locate and process foo files, and create something in blib/
    }
  }
  
  my $build = $class->new( ... );
  
  $build->add_build_element('foo');


This creates a custom subclass of C<Module::Build> that knows how to
build elements of type C<foo>.  It should place the elements in a
subdirectory of F<blib/> corresponding to items that C<Module::Build>
knows how to install - to add new capabilities in I<that> arena, see
L</Adding new types to the install process>.


=head2 Changing the order of the build process

The C<build_elements> property specifies the steps C<Module::Build>
will take when building a distribution.  To change the build order,
change the order of the entries in that property:

 # Process pod files first
 my @e = @{$build->build_elements};
 my $i = grep {$e[$_] eq 'pod'} 0..$#e;
 unshift @e, splice @e, $i, 1;

Currently, C<build_elements> has the following default value:

  [qw( PL support pm xs pod script )]

Do take care when altering this property, since there may be
non-obvious (and non-documented!) ordering dependencies in the
C<Module::Build> code.

=head2 Dealing with more than one perl installation

If you have more than one C<perl> interpreter installed on your
system, you can choose which installation to target whenever you use
C<Module::Build>.  Usually it's as simple as using the right C<perl>
in the C<perl Build.PL> step - this perl will be remembered for the
rest of the life of the generated F<Build> script.

Occasionally, however, we get it wrong.  This is because there often
is no reliable way in perl to find a path to the currently-running
perl interpreter.  When C<$^X> doesn't tell us much (e.g. when it's
something like "perl" instead of an absolute path), we do some very
effective guessing, but there's still a small chance we can get it
wrong.  Or not find one at all.

Therefore, if you want to explicitly tell C<Module::Build> which perl
binary you're targetting, you can override C<$Config{perlpath}>, like
so:

  /foo/perl Build.PL --config perlpath=/foo/perl
  ./Build --config perlpath=/foo/perl
  ./Build test --config perlpath=/foo/perl


=head2 Adding new file types to the install process

Sometimes you might have extra types of files that you want to install
alongside the standard types like F<.pm> and F<.pod> files.  For
instance, you might have a F<Foo.dat> file containing some data
related to the C<Boo::Baz> module.  Assuming the data doesn't need to
be created on the fly, the best place for it to end up is probably as
F<Boo/Baz/Foo.dat> somewhere in perl's C<@INC> path so C<Boo::Baz> can
access it easily at runtime.  The following code from a sample
C<Build.PL> file demonstrates how to accomplish this:

  use Module::Build;
  my $build = new Module::Build
    (
     module_name => 'Boo::Baz',
     ...
    );
  $build->add_build_element('dat');
  $build->create_build_script;

This will find all F<.dat> files in the F<lib/> directory, copy them
to the F<blib/lib/> directory during the C<build> action, and install
them during the C<install> action.

If your extra files aren't in the C<lib/> directory, you can
explicitly say where they are, just as you'd do with F<.pm> or F<.pod>
files:

  use Module::Build;
  my $build = new Module::Build
    (
     module_name => 'Boo::Baz',
     dat_files => {'some/dir/Foo.dat' => 'lib/Boo/Baz/Foo.dat'},
     ...
    );
  $build->add_build_element('dat');
  $build->create_build_script;

If your extra files actually need to be created on the user's machine,
you'll probably have to override the C<build> action to do so:

  use Module::Build;
  my $class = Module::Build->subclass(code => <<'EOF');
    sub ACTION_build {
      my $self = shift;
      $self->SUPER::ACTION_build(@_);
      ... create the .dat files here ...
    }
  EOF
  my $build = $class->new
    (
     module_name => 'Boo::Baz',
     ...
    );
  $build->add_build_element('dat');
  $build->create_build_script;

Please note that these examples use some capabilities of Module::Build
that first appeared in version 0.26.  Before that it could certainly
still be done, but the simple cases took a bit more work.

=head1 AUTHOR

Ken Williams, ken@mathforum.org

=head1 SEE ALSO

perl(1), Module::Build(3)

=cut
