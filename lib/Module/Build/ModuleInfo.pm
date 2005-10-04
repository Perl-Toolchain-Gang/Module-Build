package Module::Build::ModuleInfo;

# This module provides routines to gather information about
# perl modules (assuming this may be expanded in the distant
# parrot future to look at other types of modules).

use strict;

use File::Spec;
use IO::File;


my $PKG_REGEXP  = qr/^[\s\{;]*package\s+([\w:]+)/;
my $VERS_REGEXP = qr/([\$*])(((?:::|')?(?:\w+(?:::|'))*)?VERSION)\b\s*=[^=]/;


sub new_from_file {
  my $package  = shift;
  my $filename = File::Spec->rel2abs( shift );
  return undef unless defined( $filename ) && -f $filename;
  return $package->_init( undef, $filename, @_ );
}

sub new_from_module {
  my $package = shift;
  my $module  = shift;
  my %props   = @_;
  $props{inc} ||= \@INC;
  my $filename = $package->find_module_by_name( $module, $props{inc} );
  return undef unless defined( $filename ) && -f $filename;
  return $package->_init( $module, $filename, %props );
}

sub _init {
  my $package  = shift;
  my $module   = shift;
  my $filename = shift;

  my %props = @_;
  my( %valid_props, @valid_props );
  @valid_props = qw( collect_pod inc );
  @valid_props{@valid_props} = delete( @props{@valid_props} );
  warn "Unknown properties: @{[keys %props]}\n" if scalar( %props );

  my %data = (
    module   => $module,
    filename => $filename,
    version  => undef,
    packages => [],
    versions => {},
    pod          => {},
    pod_headings => [],
    collect_pod  => 0,

    %valid_props,
  );

  my $self = bless( \%data, $package );

  $self->_parse_file();

  unless ( $self->{module} && length( $self->{module} ) ) {
    my( $v, $d, $f ) = File::Spec->splitpath( $self->{filename} );
    if ( $f =~ /\.pm$/ ) {
      $f =~ s/\..+$//;
      my @candidates = grep /$f$/, @{$self->{packages}};
      $self->{module} = shift( @candidates ); # punt
    } else {
      if ( grep /main/, @{$self->{packages}} ) {
	$self->{module} = 'main';
      } else {
        $self->{module} = $self->{packages}[0] || '';
      }
    }
  }

  $self->{version} = $self->{versions}{$self->{module}}
      if defined( $self->{module} );

  return $self;
}

# class method
sub _do_find_module {
  my $package = shift;
  my $module  = shift || die 'find_module_by_name() requires a package name';
  my $dirs    = shift || \@INC;

  my $file = File::Spec->catfile(split( /::/, $module));
  foreach my $dir ( @$dirs ) {
    my $testfile = File::Spec->catfile($dir, $file);
    return [ File::Spec->rel2abs( $testfile ), $dir ]
	if -e $testfile and !-d _;  # For stuff like ExtUtils::xsubpp
    return [ File::Spec->rel2abs( "$testfile.pm" ), $dir ]
	if -e "$testfile.pm";
  }
  return;
}

# class method
sub find_module_by_name {
  my $found = shift()->_do_find_module(@_) or return;
  return $found->[0];
}

# class method
sub find_module_dir_by_name {
  my $found = shift()->_do_find_module(@_) or return;
  return $found->[1];
}

# given a line of perl code, attempt to parse it if it looks like a
# $VERSION assignment, returning sigil, full name, & package name
sub _parse_version_expression {
  my $self = shift;
  my $line = shift;

  my( $sig, $var, $pkg );
  if ( $line =~ $VERS_REGEXP ) {
    ( $sig, $var, $pkg ) = ( $1, $2, $3 );
    if ( $pkg ) {
      $pkg = ($pkg eq '::') ? 'main' : $pkg;
      $pkg =~ s/::$//;
    }
  }

  return ( $sig, $var, $pkg );
}

sub _parse_file {
  my $self = shift;

  my $filename = $self->{filename};
  my $fh = IO::File->new( $filename )
    or die( "Can't open '$filename': $!" );

  my( $in_pod, $seen_end, $need_vers ) = ( 0, 0, 0 );
  my( @pkgs, %vers, %pod, @pod );
  my $pkg = 'main';
  my $pod_sect = '';
  my $pod_data = '';

  while (defined( my $line = <$fh> )) {

    chomp( $line );
    next if $line =~ /^\s*#/;

    $in_pod = ($line =~ /^=(?!cut)/) ? 1 : ($line =~ /^=cut/) ? 0 : $in_pod;

    if ( $in_pod || $line =~ /^=cut/ ) {

      if ( $line =~ /^=head\d\s+(.+)\s*$/ ) {
	push( @pod, $1 );
	if ( $self->{collect_pod} && length( $pod_data ) ) {
          $pod{$pod_sect} = $pod_data;
          $pod_data = '';
        }
	$pod_sect = $1;


      } elsif ( $self->{collect_pod} ) {
	$pod_data .= "$line\n";

      }

    } else {

      $pod_sect = '';
      $pod_data = '';

      # parse $line to see if it's a $VERSION declaration
      my( $vers_sig, $vers_fullname, $vers_pkg ) =
	  $self->_parse_version_expression( $line );

      if ( $line =~ $PKG_REGEXP ) {
	$pkg = $1;
	push( @pkgs, $pkg ) unless grep( $pkg eq $_, @pkgs );
	$vers{$pkg} = undef unless exists( $vers{$pkg} );
	$need_vers = 1;

      # VERSION defined with full package spec, i.e. $Module::VERSION
      } elsif ( $vers_fullname && $vers_pkg ) {
	push( @pkgs, $vers_pkg ) unless grep( $vers_pkg eq $_, @pkgs );
	$need_vers = 0 if $vers_pkg eq $pkg;

	my $v =
	  $self->_evaluate_version_line( $vers_sig, $vers_fullname, $line );
	unless ( defined $vers{$vers_pkg} && length $vers{$vers_pkg} ) {
	  $vers{$vers_pkg} = $v;
	} else {
	  warn <<"EOM";
Package '$vers_pkg' already declared with version '$vers{$vers_pkg}'
ignoring new version '$v'.
EOM
	}

      # first non-comment line in undeclared package main is VERSION
      } elsif ( !exists($vers{main}) && $pkg eq 'main' && $vers_fullname ) {
	$need_vers = 0;
	my $v =
	  $self->_evaluate_version_line( $vers_sig, $vers_fullname, $line );
	$vers{$pkg} = $v;
	push( @pkgs, 'main' );

      # first non-comement line in undeclared packge defines package main
      } elsif ( !exists($vers{main}) && $pkg eq 'main' && $line =~ /\w+/ ) {
	$need_vers = 1;
	$vers{main} = '';
	push( @pkgs, 'main' );

      # only keep if this is the first $VERSION seen
      } elsif ( $vers_fullname && $need_vers ) {
	$need_vers = 0;
	my $v =
	  $self->_evaluate_version_line( $vers_sig, $vers_fullname, $line );


	unless ( defined $vers{$pkg} && length $vers{$pkg} ) {
	  $vers{$pkg} = $v;
	} else {
	  warn <<"EOM";
Package '$pkg' already declared with version '$vers{$pkg}'
ignoring new version '$v'.
EOM
	}

      }

    }

  }

  if ( $self->{collect_pod} && length($pod_data) ) {
    $pod{$pod_sect} = $pod_data;
  }

  $self->{versions} = \%vers;
  $self->{packages} = \@pkgs;
  $self->{pod} = \%pod;
  $self->{pod_headings} = \@pod;
}

sub _evaluate_version_line {
  my $self = shift;
  my( $sigil, $var, $line ) = @_;

  # Some of this code came from the ExtUtils:: hierarchy.

  my $eval = qq{q#  Hide from _packages_inside()
		 #; package Module::Build::ModuleInfo::_version;
		 no strict;

		 local $sigil$var;
		 \$$var=undef; do {
		   $line
		 }; \$$var
		};
  local $^W;

  # version.pm will change the ->VERSION method, so we mitigate the
  # potential effects here.  Unfortunately local(*UNIVERSAL::VERSION)
  # will crash perl < 5.8.1.  We also use * Foo::VERSION instead of
  # *Foo::VERSION so that old versions of CPAN.pm, etc. with a
  # too-permissive regex don't think we're actually declaring a
  # version.

  my $old_version = \&UNIVERSAL::VERSION;
  eval {require version};
  my $result = eval $eval;
  * UNIVERSAL::VERSION = $old_version;
  warn "Error evaling version line '$eval' in $self->{filename}: $@\n" if $@;

  # Unbless it if it's a version.pm object
  $result = "$result" if UNIVERSAL::isa( $result, 'version' );

  return $result;
}


############################################################

# accessors
sub name            { $_[0]->{module}           }

sub filename        { $_[0]->{filename}         }
sub packages_inside { @{$_[0]->{packages}}      }
sub pod_inside      { @{$_[0]->{pod_headings}}  }
sub contains_pod    { $#{$_[0]->{pod_headings}} }

sub version {
    my $self = shift;
    my $mod  = shift || $self->{module};
    my $vers;
    if ( defined( $mod ) && length( $mod ) &&
	 exists( $self->{versions}{$mod} ) ) {
	return $self->{versions}{$mod};
    } else {
	return undef;
    }
}

sub pod {
    my $self = shift;
    my $sect = shift;
    if ( defined( $sect ) && length( $sect ) &&
	 exists( $self->{pod}{$sect} ) ) {
	return $self->{pod}{$sect};
    } else {
	return undef;
    }
}

1;

__END__

=head1 NAME

ModuleInfo - Gather package and POD information from a perl module files

=head1 DESCRIPTION

=head2 new_from_file( $filename [ , collect_pod => 1 ] )

Construct a ModuleInfo object given the path to a file. Takes an optional
arguement C<collect_pod> which is a boolean that determines whether
POD data is collected and stored for reference. POD data is not
collected by default. POD headings are always collected.

=head2 new_from_module( $module [ , collect_pod => 1, inc => \@dirs ] )

Construct a ModuleInfo object given a module or package name. In addition
to accepting the C<collect_pod> argument as described above, this
method accepts a C<inc> arguemnt which is a reference to an array of
of directories to search for the module. If none are given, the
default is @INC.

=head2 name( )

Returns the name of the package represented by this module. If there
are more than one packages, it makes a best guess based on the
filename. If it's a script (i.e. not a *.pm) the package name is
'main'.

=head2 version( [ $package ] )

Returns the version as defined by the $VERSION variable for the
package as returned by the C<name> method if no arguments are
given. If given the name of a package it will attempt to return the
version of that package if it is specified in the file.

=head2 filename( )

Returns the absolute path to the file.

=head2 packages_inside( )

Returns a list of packages.

=head2 pod_inside( )

Returns a list of POD sections.

=head2 contains_pod( )

Returns true if there is any POD in the file.

=head2 pod( $section )

Returns the POD data in the given section.

=head2 find_module_by_name( $module [ , \@dirs ] )

Returns the path to a module given the module or package name. A list
of directories can be passed in as an optional paramater, otherwise
@INC is searched.

Can be called as either an object or a class method.

=head2 find_module_dir_by_name( $module [ , \@dirs ] )

Returns the entry in C<@dirs> (or C<@INC> by default) that contains
the module C<$module>. A list of directories can be passed in as an
optional paramater, otherwise @INC is searched.

Can be called as either an object or a class method.

=cut
