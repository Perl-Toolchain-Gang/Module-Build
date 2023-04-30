package Module::Build::Compat;

use strict;
use warnings;
our $VERSION = '0.42_35';

use File::Basename ();
use File::Spec;
use Config;
use Module::Build;
use Module::Metadata;
use version;
use Data::Dumper;

my %convert_installdirs = (
    PERL        => 'core',
    SITE        => 'site',
    VENDOR      => 'vendor',
);

my %makefile_to_build =
  (
   TEST_VERBOSE => 'verbose',
   VERBINST     => 'verbose',
   INC          => sub { map {(extra_compiler_flags => $_)} Module::Build->split_like_shell(shift) },
   POLLUTE      => sub { (extra_compiler_flags => '-DPERL_POLLUTE') },
   INSTALLDIRS  => sub { (installdirs => $convert_installdirs{uc shift()}) },
   LIB          => sub {
       my $lib = shift;
       my %config = (
           installprivlib  => $lib,
           installsitelib  => $lib,
           installarchlib  => "$lib/$Config{archname}",
           installsitearch => "$lib/$Config{archname}"
       );
       return map { (config => "$_=$config{$_}") } sort keys %config;
   },

   # Convert INSTALLVENDORLIB and friends.
   (
       map {
           my $name = $_;
           $name => sub {
                 my @ret = (config => lc($name) . "=" . shift );
                 print STDERR "# Converted to @ret\n";

                 return @ret;
           }
       } qw(
         INSTALLARCHLIB  INSTALLSITEARCH     INSTALLVENDORARCH
         INSTALLPRIVLIB  INSTALLSITELIB      INSTALLVENDORLIB
         INSTALLBIN      INSTALLSITEBIN      INSTALLVENDORBIN
         INSTALLSCRIPT   INSTALLSITESCRIPT   INSTALLVENDORSCRIPT
         INSTALLMAN1DIR  INSTALLSITEMAN1DIR  INSTALLVENDORMAN1DIR
         INSTALLMAN3DIR  INSTALLSITEMAN3DIR  INSTALLVENDORMAN3DIR
       )
   ),

   # Some names they have in common
   map {$_, lc($_)} qw(DESTDIR PREFIX INSTALL_BASE UNINST),
  );

my %macro_to_build = %makefile_to_build;
# "LIB=foo make" is not the same as "perl Makefile.PL LIB=foo"
delete $macro_to_build{LIB};

sub _merge_prereq {
  my ($req, $breq) = @_;
  $req ||= {};
  $breq ||= {};

  # validate formats
  for my $p ( $req, $breq ) {
    for my $k (sort keys %$p) {
      next if $k eq 'perl';

      my $v_obj = eval { version->new($p->{$k}) };
      if ( ! defined $v_obj ) {
          die "A prereq of the form '$p->{$k}' for '$k' is not supported by Module::Build::Compat ( use a simpler version like '0.05' or 'v1.4.25' )\n";
      }

      # It seems like a lot of people trip over "0.1.2" stuff, so we help them here...
      if ( $v_obj->is_qv ) {
        my $proper_ver = $v_obj->numify;
        warn "Dotted-decimal prereq '$p->{$k}' for '$k' is not portable - converting it to '$proper_ver'\n";
        $p->{$k} = $proper_ver;
      }
    }
  }
  # merge
  my $merge = { %$req };
  for my $k ( keys %$breq ) {
    my $v1 = $merge->{$k} || 0;
    my $v2 = $breq->{$k};
    $merge->{$k} = $v1 > $v2 ? $v1 : $v2;
  }
  return %$merge;
}


sub create_makefile_pl {
  my ($package, $type, $build, %args) = @_;

  die "Don't know how to build Makefile.PL of type '$type'"
    unless $type =~ /^(small|passthrough|traditional)$/;

  if ($type eq 'passthrough') {
    $build->log_warn(<<"HERE");

IMPORTANT NOTE: The '$type' style of Makefile.PL is deprecated and
may be removed in a future version of Module::Build in favor of the
'configure_requires' property.  See Module::Build::Compat
documentation for details.

HERE
  }

  my $fh;
  if ($args{fh}) {
    $fh = $args{fh};
  } else {
    $args{file} ||= 'Makefile.PL';
    local $build->{properties}{quiet} = 1;
    $build->delete_filetree($args{file});
    open($fh, '>', "$args{file}") or die "Can't write $args{file}: $!";
  }

  print {$fh} "# Note: this file was auto-generated by ", __PACKAGE__, " version $VERSION\n";

  # Minimum perl version should be specified as "require 5.XXXXXX" in
  # Makefile.PL
  my $requires = $build->requires;
  if ( my $minimum_perl = $requires->{perl} ) {
    my $min_ver = version->new($minimum_perl)->numify;
    print {$fh} "require $min_ver;\n";
  }

  # If a *bundled* custom subclass is being used, make sure we add its
  # directory to @INC.  Also, lib.pm always needs paths in Unix format.
  my $subclass_load = '';
  if (ref($build) ne "Module::Build") {
    my $subclass_dir = $package->subclass_dir($build);

    if (File::Spec->file_name_is_absolute($subclass_dir)) {
      my $base_dir = $build->base_dir;

      if ($build->dir_contains($base_dir, $subclass_dir)) {
	$subclass_dir = File::Spec->abs2rel($subclass_dir, $base_dir);
	$subclass_dir = $package->unixify_dir($subclass_dir);
        $subclass_load = "use lib '$subclass_dir';";
      }
      # Otherwise, leave it the empty string

    } else {
      $subclass_dir = $package->unixify_dir($subclass_dir);
      $subclass_load = "use lib '$subclass_dir';";
    }
  }

  if ($type eq 'small') {
    printf {$fh} <<'EOF', $subclass_load, ref($build), ref($build);
    use Module::Build::Compat 0.02;
    %s
    Module::Build::Compat->run_build_pl(args => \@ARGV);
    require %s;
    Module::Build::Compat->write_makefile(build_class => '%s');
EOF

  } elsif ($type eq 'passthrough') {
    printf {$fh} <<'EOF', $subclass_load, ref($build), ref($build);

    unless (eval "use Module::Build::Compat 0.02; 1" ) {
      print "This module requires Module::Build to install itself.\n";

      require ExtUtils::MakeMaker;
      my $yn = ExtUtils::MakeMaker::prompt
	('  Install Module::Build now from CPAN?', 'y');

      unless ($yn =~ /^y/i) {
	die " *** Cannot install without Module::Build.  Exiting ...\n";
      }

      require Cwd;
      require File::Spec;
      require CPAN;

      # Save this 'cause CPAN will chdir all over the place.
      my $cwd = Cwd::cwd();

      CPAN::Shell->install('Module::Build::Compat');
      CPAN::Shell->expand("Module", "Module::Build::Compat")->uptodate
	or die "Couldn't install Module::Build, giving up.\n";

      chdir $cwd or die "Cannot chdir() back to $cwd: $!";
    }
    eval "use Module::Build::Compat 0.02; 1" or die $@;
    %s
    Module::Build::Compat->run_build_pl(args => \@ARGV);
    my $build_script = 'Build';
    $build_script .= '.com' if $^O eq 'VMS';
    exit(0) unless(-e $build_script); # cpantesters convention
    require %s;
    Module::Build::Compat->write_makefile(build_class => '%s');
EOF

  } elsif ($type eq 'traditional') {

    my (%MM_Args, %prereq);
    if (eval "use Tie::IxHash 1.2; 1") {
      tie %MM_Args, 'Tie::IxHash'; # Don't care if it fails here
      tie %prereq,  'Tie::IxHash'; # Don't care if it fails here
    }

    my %name = ($build->module_name
		? (NAME => $build->module_name)
		: (DISTNAME => $build->dist_name));

    my %version = ($build->dist_version_from
		   ? (VERSION_FROM => $build->dist_version_from)
		   : (VERSION      => $build->dist_version)
		  );
    %MM_Args = (%name, %version);

    %prereq = _merge_prereq( $build->requires, $build->build_requires );
    %prereq = map {$_, $prereq{$_}} sort keys %prereq;

     delete $prereq{perl};
    $MM_Args{PREREQ_PM} = \%prereq;

    $MM_Args{INSTALLDIRS} = $build->installdirs eq 'core' ? 'perl' : $build->installdirs;

    $MM_Args{EXE_FILES} = [ sort keys %{$build->script_files} ] if $build->script_files;

    $MM_Args{PL_FILES} = $build->PL_files || {};

    if ($build->recursive_test_files) {
        $MM_Args{test} = { TESTS => join q{ }, $package->_test_globs($build) };
    }

    local $Data::Dumper::Terse = 1;
    my $args = Data::Dumper::Dumper(\%MM_Args);
    $args =~ s/\{(.*)\}/($1)/s;

    print $fh <<"EOF";
use ExtUtils::MakeMaker;
WriteMakefile
$args;
EOF
  }
}

sub _test_globs {
  my ($self, $build) = @_;

  return map { File::Spec->catfile($_, '*.t') }
         @{$build->rscan_dir('t', sub { -d $File::Find::name })};
}

sub subclass_dir {
  my ($self, $build) = @_;

  return (Module::Metadata->find_module_dir_by_name(ref $build)
	  || File::Spec->catdir($build->config_dir, 'lib'));
}

sub unixify_dir {
  my ($self, $path) = @_;
  return join '/', File::Spec->splitdir($path);
}

sub makefile_to_build_args {
  my $class = shift;
  my @out;
  foreach my $arg (@_) {
    next if $arg eq '';

    my ($key, $val) = ($arg =~ /^(\w+)=(.+)/ ? ($1, $2) :
		       die "Malformed argument '$arg'");

    # Do tilde-expansion if it looks like a tilde prefixed path
    ( $val ) = Module::Build->_detildefy( $val ) if $val =~ /^~/;

    if (exists $makefile_to_build{$key}) {
      my $trans = $makefile_to_build{$key};
      push @out, $class->_argvify( ref($trans) ? $trans->($val) : ($trans => $val) );
    } elsif (exists $Config{lc($key)}) {
      push @out, $class->_argvify( config => lc($key) . "=$val" );
    } else {
      # Assume M::B can handle it in lowercase form
      push @out, $class->_argvify("\L$key" => $val);
    }
  }
  return @out;
}

sub _argvify {
  my ($self, @pairs) = @_;
  my @out;
  while (@pairs) {
    my ($k, $v) = splice @pairs, 0, 2;
    push @out, ("--$k", $v);
  }
  return @out;
}

sub makefile_to_build_macros {
  my @out;
  my %config; # must accumulate and return as a hashref
  foreach my $macro (sort keys %macro_to_build) {
    my $trans = $macro_to_build{$macro};
    # On some platforms (e.g. Cygwin with 'make'), the mere presence
    # of "EXPORT: FOO" in the Makefile will make $ENV{FOO} defined.
    # Therefore we check length() too.
    next unless exists $ENV{$macro} && length $ENV{$macro};
    my $val = $ENV{$macro};
    my @args = ref($trans) ? $trans->($val) : ($trans => $val);
    while (@args) {
      my ($k, $v) = splice(@args, 0, 2);
      if ( $k eq 'config' ) {
        if ( $v =~ /^([^=]+)=(.*)$/ ) {
          $config{$1} = $2;
        }
        else {
          warn "Couldn't parse config '$v'\n";
        }
      }
      else {
        push @out, ($k => $v);
      }
    }
  }
  push @out, (config => \%config) if %config;
  return @out;
}

sub run_build_pl {
  my ($pack, %in) = @_;
  $in{script} ||= 'Build.PL';
  my @args = $in{args} ? $pack->makefile_to_build_args(@{$in{args}}) : ();
  print "# running $in{script} @args\n";
  Module::Build->run_perl_script($in{script}, [], \@args) or die "Couldn't run $in{script}: $!";
}

sub fake_makefile {
  my ($self, %args) = @_;
  unless (exists $args{build_class}) {
    warn "Unknown 'build_class', defaulting to 'Module::Build'\n";
    $args{build_class} = 'Module::Build';
  }
  my $class = $args{build_class};

  my $perl = $class->find_perl_interpreter;

  # VMS MMS/MMK need to use MCR to run the Perl image.
  $perl = 'MCR ' . $perl if $self->_is_vms_mms;

  my $noop = ($class->is_windowsish ? 'rem>nul'  :
	      $self->_is_vms_mms    ? 'Continue' :
	      'true');

  my $filetype = $class->is_vmsish ? '.COM' : '';

  my $Build = 'Build' . $filetype . ' --makefile_env_macros 1';
  my $unlink = $class->oneliner('1 while unlink $ARGV[0]', [], [$args{makefile}]);
  $unlink =~ s/\$/\$\$/g unless $class->is_vmsish;

  my $maketext = join '', map { "$_=\n" } sort keys %macro_to_build;

  $maketext .= ($^O eq 'os2' ? "SHELL = sh\n\n"
                    : $^O eq 'MSWin32' && $Config{make} =~ /gmake/
                    ? "SHELL = $ENV{COMSPEC}\n\n" : "\n\n");

  $maketext .= <<"EOF";
all : force_do_it
	$perl $Build
realclean : force_do_it
	$perl $Build realclean
	$unlink
distclean : force_do_it
	$perl $Build distclean
	$unlink


force_do_it :
	@ $noop
EOF

  foreach my $action ($class->known_actions) {
    next if $action =~ /^(all|distclean|realclean|force_do_it)$/;  # Don't double-define
    $maketext .= <<"EOF";
$action : force_do_it
	$perl $Build $action
EOF
  }

  if ($self->_is_vms_mms) {
    # Roll our own .EXPORT as MMS/MMK don't honor that directive.
    $maketext .= "\n.FIRST\n\t\@ $noop\n";
    for my $macro (sort keys %macro_to_build) {
      $maketext .= ".IFDEF $macro\n\tDEFINE $macro \"\$($macro)\"\n.ENDIF\n";
    }
    $maketext .= "\n";
  }
  else {
    $maketext .= "\n.EXPORT : " . join(' ', sort keys %macro_to_build) . "\n\n";
  }

  return $maketext;
}

sub fake_prereqs {
  my $file = File::Spec->catfile('_build', 'prereqs');
  open(my $fh, '<', "$file") or die "Can't read $file: $!";
  my $prereqs = eval do {local $/; <$fh>};
  close $fh;

  my %merged = _merge_prereq( $prereqs->{requires}, $prereqs->{build_requires} );
  my @prereq;
  foreach (sort keys %merged) {
    next if $_ eq 'perl';
    push @prereq, "$_=>q[$merged{$_}]";
  }
  return unless @prereq;
  return "#     PREREQ_PM => { " . join(", ", @prereq) . " }\n\n";
}


sub write_makefile {
  my ($pack, %in) = @_;

  unless (exists $in{build_class}) {
    warn "Unknown 'build_class', defaulting to 'Module::Build'\n";
    $in{build_class} = 'Module::Build';
  }
  my $class = $in{build_class};
  $in{makefile} ||= $pack->_is_vms_mms ? 'Descrip.MMS' : 'Makefile';

  open  MAKE, "> $in{makefile}" or die "Cannot write $in{makefile}: $!";
  print MAKE $pack->fake_prereqs;
  print MAKE $pack->fake_makefile(%in);
  close MAKE;
}

sub _is_vms_mms {
  return Module::Build->is_vmsish && ($Config{make} =~ m/MM[SK]/i);
}

1;
__END__

=for :stopwords passthrough

=head1 NAME

Module::Build::Compat - Compatibility with ExtUtils::MakeMaker

=head1 SYNOPSIS

  # In a Build.PL :
  use Module::Build;
  my $build = Module::Build->new
    ( module_name => 'Foo::Bar',
      license     => 'perl',
      create_makefile_pl => 'traditional' );
  ...


=head1 DESCRIPTION

Because C<ExtUtils::MakeMaker> has been the standard way to distribute
modules for a long time, many tools (CPAN.pm, or your system
administrator) may expect to find a working F<Makefile.PL> in every
distribution they download from CPAN.  If you want to throw them a
bone, you can use C<Module::Build::Compat> to automatically generate a
F<Makefile.PL> for you, in one of several different styles.

C<Module::Build::Compat> also provides some code that helps out the
F<Makefile.PL> at runtime.

=head1 WARNING

Note that C<Module::Build::Compat> more often causes installation issues
than solves them, and each of the three F<Makefile.PL> generation styles
has unique compatibility or functionality issues that are unlikely to be
fixed. Thus, the use of this module and C<create_makefile_pl> is
discouraged.

=head1 METHODS

=over 4

=item create_makefile_pl($style, $build)

Creates a F<Makefile.PL> in the current directory in one of several
styles, based on the supplied C<Module::Build> object C<$build>.  This is
typically controlled by passing the desired style as the
C<create_makefile_pl> parameter to C<Module::Build>'s C<new()> method;
the F<Makefile.PL> will then be automatically created during the
C<distdir> action.

The currently supported styles are:

=over 4

=item traditional

A F<Makefile.PL> will be created in the "traditional" style, i.e. it will
use C<ExtUtils::MakeMaker> and won't rely on C<Module::Build> at all.
In order to create the F<Makefile.PL>, we'll include the C<requires> and
C<build_requires> dependencies as the C<PREREQ_PM> parameter.

You don't want to use this style if during the C<perl Build.PL> stage
you ask the user questions, or do some auto-sensing about the user's
environment, or if you subclass C<Module::Build> to do some
customization, because the vanilla F<Makefile.PL> won't do any of that.
Many standard C<Module::Build> features such as C<test_requires> are also
not supported.

=item small

A small F<Makefile.PL> will be created that passes all functionality
through to the F<Build.PL> script in the same directory.  The user must
already have C<Module::Build> installed in order to use this, or else
they'll get a module-not-found error.

This style attempts (with varying success) to translate the F<Makefile.PL>
protocol to F<Build.PL>, and is unnecessary on any modern toolchain that
recognizes C<configure_requires> metadata described below, as F<Build.PL>
will be run by default in this case. See
L<https://rt.cpan.org/Public/Bug/Display.html?id=75936> for an example of
the issues it may cause.

=item passthrough (DEPRECATED)

This is just like the C<small> option above, but if C<Module::Build> is
not already installed on the user's system, the script will offer to
use C<CPAN.pm> to download it and install it before continuing with
the build.

This option has been deprecated and may be removed in a future version
of Module::Build.  Modern CPAN.pm and CPANPLUS will recognize the
C<configure_requires> metadata property and install Module::Build before
running Build.PL if Module::Build is listed and Module::Build now
adds itself to configure_requires by default.

Perl 5.10.1 includes C<configure_requires> support.  In the future, when
C<configure_requires> support is deemed sufficiently widespread, the
C<passthrough> style will be removed.

=back

=item run_build_pl(args => \@ARGV)

This method runs the F<Build.PL> script, passing it any arguments the
user may have supplied to the C<perl Makefile.PL> command.  Because
C<ExtUtils::MakeMaker> and C<Module::Build> accept different arguments, this
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

This method writes a 'dummy' F<Makefile> that will pass all commands
through to the corresponding C<Module::Build> actions.

C<write_makefile()> accepts the following named parameters:

=over 4

=item makefile

The name of the file to write - defaults to the string C<Makefile>.

=back

=back


=head1 SCENARIOS

So, some common scenarios are:

=over 4

=item 1.

Just include a F<Build.PL> script (without a F<Makefile.PL>
script), and give installation directions in a F<README> or F<INSTALL>
document explaining how to install the module.  In particular, explain
that the user must install C<Module::Build> before installing your
module.

Note that if you do this, you may make things easier for yourself, but
harder for people with older versions of CPAN or CPANPLUS on their
system, because those tools generally only understand the
F<Makefile.PL>/C<ExtUtils::MakeMaker> way of doing things.

=item 2.

Include a F<Build.PL> script and a "traditional" F<Makefile.PL>,
created either manually or with C<create_makefile_pl()>.  Users won't
ever have to install C<Module::Build> if they use the F<Makefile.PL>, but
they won't get to take advantage of C<Module::Build>'s extra features
either.

For good measure, of course, test both the F<Makefile.PL> and the
F<Build.PL> before shipping.

=item 3.

Include a F<Build.PL> script and a "pass-through" F<Makefile.PL>
built using C<Module::Build::Compat>.  This will mean that people can
continue to use the "old" installation commands, and they may never
notice that it's actually doing something else behind the scenes.  It
will also mean that your installation process is compatible with older
versions of tools like CPAN and CPANPLUS.

=back


=head1 AUTHOR

Ken Williams <kwilliams@cpan.org>


=head1 COPYRIGHT

Copyright (c) 2001-2006 Ken Williams.  All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.


=head1 SEE ALSO

L<Module::Build>(3), L<ExtUtils::MakeMaker>(3)


=cut
