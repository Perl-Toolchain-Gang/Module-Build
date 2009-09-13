package inc::latest;
use strict;
use warnings;

use Carp;
use File::Basename  ();
use File::Spec      ();
use File::Path      ();
use IO::File        ();
use File::Copy      ();

sub import {
  my ($package, $mod, @args) = @_;
  return unless(defined $mod);

  my $inc_path = './inc/latest.pm';
  if(-e $inc_path) {
    # delete our methods
    delete $inc::latest::{$_} for(keys %inc::latest::);
    # load the bundled module
    require $inc_path;
    my $import = inc::latest->can('import');
    goto $import;
  }

  # author mode - just load the modules
  $package->load_module($mod, @args);
}

my @loaded_modules;
sub loaded_modules {@loaded_modules}

sub load_module {
  my $package = shift;
  my ($mod, @args) = @_;

  push(@loaded_modules, $mod);
  (my $pm = $mod) =~ s#::#/#g;
  $pm .= '.pm';
  require($pm);
  if(@args and my $import = $mod->can('import')) {
    goto $import;
  }
}

sub write {
  my $package = shift;
  my ($where) = @_;

  warn "should really be writing in inc/" unless $where =~ /inc$/;
  File::Path::mkpath $where;
  my $fh = IO::File->new( File::Spec->catfile($where,'latest.pm'), "w" );
  print {$fh} do {local $/; <DATA>};
}

sub bundle_module {
  my ($package, $module, $where) = @_;
  
  # create inc/inc_$foo
  (my $dist = $module) =~ s{::}{-}g;
  my $inc_lib = File::Spec->catdir($where,"inc_$dist");
  File::Path::mkpath $inc_lib;

  # get list of files to copy
  require ExtUtils::Installed;
  my $inst = ExtUtils::Installed->new;
  my @files = $inst->files( $module, 'prog' );

  # figure out prefix
  my $mod_path = quotemeta $package->_mod2path( $module );
  my ($prefix) = grep { /$mod_path$/ } @files;
  $prefix =~ s{$mod_path$}{};

  # copy files
  for my $from ( @files ) {
    next unless $from =~ /\.pm$/;
    (my $mod_path = $from) =~ s{^\Q$prefix\E}{};
    my $to = File::Spec->catfile( $inc_lib, $mod_path );
    File::Path::mkpath(File::Basename::dirname($to));
    File::Copy::copy( $from, $to ) or die "Couldn't copy '$from' to '$to': $!";
  }
  return 1;
}

# Translate a module name into a directory/file.pm to search for in @INC
sub _mod2path {
  my ($self, $mod) = @_;
  my @parts = split /::/, $mod;
  $parts[-1] .= '.pm';
  return $parts[0] if @parts == 1;
  return File::Spec->catfile(@parts);
}

1;


=head1 NAME

inc::latest - use modules bundled in inc/ if they are newer than installed ones

=head1 SYNOPSIS

  # in Build.PL
  use inc::latest 'Module::Build';

=head1 DESCRIPTION

The C<inc::latest> module helps bootstrap configure-time dependencies for CPAN
distributions.  These dependencies get bundled into the C<inc> directory within
a distribution and are used by Build.PL (or Makefile.PL).  

Arguments to C<inc::latest> are module names that are checked against both the
current C<@INC> array and against specially-named directories in C<inc>.  If
the bundled verison is newer than the installed one (or the module isn't
installed, then, the bundled directory is added to the start of <@INC> and the
module is loaded from there.

There are actually two variations of C<inc::latest> -- one for authors and one
for the C<inc> directory.  For distribution authors, the C<inc::latest>
installed in the system will record modules loaded via C<inc::latest> and can
be used to create the bundled files in C<inc>, including writing the second
variation as C<inc/latest.pm>.

This second C<inc::latest> is the one that is loaded in a distribution being
installed (e.g. from Build.PL).  This bundled C<inc::latest> is the one
that determines which module to load.

=head2 Special notes on bundling

The C<inc::latest> module creates bundled directories based on the packlist
file of an installed distribution.  Even though C<inc::latest> takes module
name arguments, it is better to think of it as bundling and making available
entire I<distributions>.

Thus, the module-name provided should usually be the "top-level" module name of
a distribution, though this is not strictly required.  For example,
L<Module::Build> has a number of heuristics to map module names to packlists,
allowing users to do things like this:

  use inc::latest 'Devel::AssertOS::Unix';

even though Devel::AssertOS::Unix is contained within the Devel-CheckOS
distribution.

At the current time, packlists are required.  Thus, bundling dual-core modules
may require a 'forced install' over versions in the latest version of perl
in order to create the necessary packlist for bundling.

=head1 USAGE

When calling C<use>, the bundled C<inc::latest> takes a single module name and
optional arguments to pass to that module's own import method.

  use 'inc::latest' 'Foo::Bar' qw/foo bar baz/;

=head2 Author-mode

=over 4

=item loaded_modules()

DOCUMENT THIS

=item write()

DOCUMENT THIS

=item bundle_module()

DOCUMENT THIS

=back

=head2 As bundled in inc/

All methods are private.  Only the C<import> method is public.

=head1 AUTHOR

Eric Wilhelm <ewilhelm@cpan.org>, David Golden <dagolden@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2009 by Eric Wilhelm and David Golden

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Module::Build>

=cut

__DATA__
package inc::latest;

use strict;
use File::Spec;
use IO::File;

sub import {
  my ($pack, $mod, @args) = @_;
  my $file = $pack->_mod2path($mod);

  if ($INC{$file}) {
    # Already loaded
    return $pack->_load($mod, @args);
  }

  # A bundled copy must be present
  my ($bundled, $bundled_dir) = $pack->_search_bundled($file)
    or die "No bundled copy of $mod found";
  
  my $from_inc = $pack->_search_INC($file);
  unless ($from_inc) {
    # Only bundled is available
    unshift(@INC, $bundled_dir);
    return $pack->_load($mod, @args);
  }

  if (_version($from_inc) >= _version($bundled)) {
    # Ignore the bundled copy
    return $pack->_load($mod, @args);
  }

  # Load the bundled copy
  unshift(@INC, $bundled_dir);
  return $pack->_load($mod, @args);
}

sub _version {
  require ExtUtils::MakeMaker;
  return ExtUtils::MM->parse_version(shift);
}

sub _load {
  my ($self, $mod, @args) = @_;
  eval "require $mod";
  die $@ if $@;
  $mod->import(@args);
  return;
}

sub _search_bundled {
  my ($self, $file) = @_;

  my $mypath = 'inc';

  local *DH;   # Maintain 5.005 compatibility
  opendir DH, $mypath or die "Can't open directory $mypath: $!";

  while (defined(my $e = readdir DH)) {
    next unless $e =~ /^inc_/;
    my $try = File::Spec->catfile($mypath, $e, $file);
    
    return($try, File::Spec->catdir($mypath, $e)) if -e $try;
  }
  return;
}

# Look for the given path in @INC.
sub _search_INC {
  # TODO: doesn't handle coderefs or arrayrefs or objects in @INC, but
  # it probably should
  my ($self, $file) = @_;

  foreach my $dir (@INC) {
    next if ref $dir;
    my $try = File::Spec->catfile($dir, $file);
    return $try if -e $try;
  }

  return;
}

# Translate a module name into a directory/file.pm to search for in @INC
sub _mod2path {
  my ($self, $mod) = @_;
  my @parts = split /::/, $mod;
  $parts[-1] .= '.pm';
  return $parts[0] if @parts == 1;
  return File::Spec->catfile(@parts);
}

1;

