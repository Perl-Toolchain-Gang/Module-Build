
package Module::Build::Compat;
$VERSION = '0.02';

use strict;
use File::Spec;
use IO::File;
use Config;

my %makefile_to_build = 
  (
   PREFIX  => 'prefix',
   LIB     => 'lib',
  );

sub makefile_to_build_args {
  shift;
  my @out;
  foreach my $arg (@_) {
    my ($key, $val) = $arg =~ /^(\w+)=(.+)/ or die "Malformed argument '$arg'";
    if (exists $Config{lc($key)}) {
      push @out, lc($key) . "=$val";
    } elsif (exists $makefile_to_build{$key}) {
      push @out, "$makefile_to_build{$key}=$val";
    } else {
      die "Unknown parameter '$key'";
    }
  }
  return @out;
}

sub run_build_pl {
  my ($pack, %in) = @_;
  $in{script} ||= 'Build.PL';
  my @args = $in{args} ? $pack->makefile_to_build_args(@{$in{args}}) : ();
  print "$^X $in{script} @args\n";
  system($^X, $in{script}, @args) == 0 or die "Couldn't run $in{script}: $!";
}

sub fake_makefile {
  my $makefile = $_[1];
  my $build = File::Spec->catfile( '.', 'Build' );

  return <<"EOF";
all :
	$^X $build
realclean :
	$^X $build realclean
	$^X -e unlink -e shift $makefile
.DEFAULT :
	$^X $build \$@
.PHONY   : install manifest
EOF
}

sub fake_prereqs {
  my $file = File::Spec->catfile('_build', 'prereqs');
  my $fh = IO::File->new("< $file") or die "Can't read $file: $!";
  my $prereqs = eval do {local $/; <$fh>};
  close $fh;
  
  my @prereq;
  foreach my $section (qw/build_requires requires recommends/) {
    foreach (keys %{$prereqs->{$section}}) {
      next if $_ eq 'perl';
      push @prereq, "$_=>q[$prereqs->{$section}{$_}]";
    }
  }

  return unless @prereq;
  return "#     PREREQ_PM => { " . join(", ", @prereq) . " }\n\n";
}


sub write_makefile {
  my ($pack, %in) = @_;
  $in{makefile} ||= 'Makefile';
  open  MAKE, "> $in{makefile}" or die "Cannot write $in{makefile}: $!";
  print MAKE $pack->fake_prereqs;
  print MAKE $pack->fake_makefile($in{makefile});
  close MAKE;
}

1;
__END__


=head1 NAME

Module::Build::Compat - Compatibility with ExtUtils::MakeMaker

=head1 SYNOPSIS

Here's a Makefile.PL that passes all functionality through to
C<Module::Build>:

  use Module::Build::Compat;
  Module::Build::Compat->run_build_pl(args => \@ARGV);
  Module::Build::Compat->write_makefile();


Or, here's one that's more careful about sensing whether
C<Module::Build> is already installed, and will offer to install it if
it's missing:

  unless (eval "use Module::Build::Compat 0.02; 1" ) {
    print "This module requires Module::Build to install itself.\n";
    
    require ExtUtils::MakeMaker;
    my $yn = ExtUtils::MakeMaker::prompt
      ('  Install Module::Build from CPAN?', 'y');
    
    if ($yn =~ /^y/i) {
      require Cwd;
      require File::Spec;
      require CPAN;
      
      # Save this 'cause CPAN will chdir all over the place.
      my $cwd = Cwd::cwd();
      my $makefile = File::Spec->rel2abs($0);
      
      CPAN::Shell->install('Module::Build::Compat');
      
      chdir $cwd or die "Cannot chdir() back to $cwd: $!";
      exec $^X, $makefile, @ARGV;  # Redo now that we have Module::Build
    } else {
      warn " *** Cannot install without Module::Build.  Exiting ...\n";
      exit 1;
    }
  }
  Module::Build::Compat->run_build_pl(args => \@ARGV);
  Module::Build::Compat->write_makefile();

=head1 DESCRIPTION

This module helps you build a Makefile.PL that passes all
functionality through to Module::Build.

There are (at least) two good ways to distribute a module that can be
installed using either C<perl Build.PL; Build; ...> or 
C<perl Makefile.PL; make; ...>.  For each way, you include both a
Makefile.PL and a Build.PL script with your distribution.  The
difference is in whether the Makefile.PL is a pass-through to
Module::Build actions, or a normal ExtUtils::MakeMaker-using script.
If it's the latter, you don't need this module - but you'll have to
maintain both the Build.PL and Makefile.PL scripts, and things like
the prerequisite lists and any other customization duplicated in the
scripts will probably become a pain in the ass.

For this reason, you might I<require> that the user have Module::Build
installed, and then the C<make> commands just pass through to the
corresponding Module::Build actions.  That's what this module lets you
do.

A typical Makefile.PL is shown above in L<SYNOPSIS>.

So, some common scenarios are:

=over 4

=item 1.  Just include a Build.PL script (without a Makefile.PL
script), and give installation directions in a README or INSTALL
document explaining how to install the module.  In particular, explain
that the user must install Module::Build before installing your
module.  I prefer this method, mainly because I believe that the woes
and hardships of doing this are far less significant than most people
would have you believe.  It's also the simplest method, which is nice.

=item 2.  Include a Build.PL script and a "regular" Makefile.PL.  This
may make things easiest for your users, but hardest for you, as you
try to maintain two separate installation scripts.

=item 3.  Include a Build.PL script and a "pass-through" Makefile.PL
built using Module::Build::Compat.  This will mean that people can
continue to use the "old" installation commands, and they may never
notice that it's actually doing something else behind the scenes.

=back

=head1 METHODS

=over 4

=item run_build_pl()

This method runs the Build.PL script, passing it any arguments the
user may have supplied to the C<perl Makefile.PL> command.  Because
ExtUtils::MakeMaker and Module::Build accept different arguments, this
method also performs some translation between the two.

C<run_build_pl()> accepts the following named parameters:

=over 4

=item args

The C<args> parameter specifies the parameters that would usually
appear on the command line of the C<perl Makefile.PL> command -
typically you'll just pass a reference to C<@ARGV>.

=item script

This is the filename of the script to run - it defaults to C<Build.PL>.

=back


=item write_makefile()

This method writes a 'dummy' Makefile that will pass all commands
through to the corresponding Module::Build actions.

C<write_makefile()> accepts the following named parameters:

=over 4

=item makefile

The name of the file to write - defaults to the string C<Makefile>.

=back

=back

=head1 AUTHOR

Ken Williams, ken@mathforum.org

=head1 SEE ALSO

Module::Build(3), ExtUtils::MakeMaker(3)

=cut
