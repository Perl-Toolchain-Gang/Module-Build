package DistGen;

use strict;
use warnings;

use vars qw( $VERSION $VERBOSE );

$VERSION = '0.01';
$VERBOSE = 0;


use Cwd ();
use File::Basename ();
use File::Find ();
use File::Path ();
use File::Spec ();


sub new {
  my $package = shift;
  my %options = @_;

  $options{name} ||= 'Simple';
  $options{dir}  ||= File::Spec->curdir();

  my %data = (
    skip_manifest => 0,
    xs_module     => 0,
    %options,
  );
  my $self = bless( \%data, $package );

  $self->_gen_default_filedata();

  return $self;
}


sub _gen_default_filedata {
  my $self = shift;

  $self->add_file( 'Build.PL', <<"---" ) unless $self->{filedata}{'Build.PL'};
use strict;
use warnings;

use Module::Build;

my \$builder = Module::Build->new(
    module_name         => '$self->{name}',
    license             => 'perl',
);

\$builder->create_build_script();
---

  my $module_filename =
    join( '/', ('lib', split(/::/, $self->{name})) ) . '.pm';

  unless ( $self->{xs_module} ) {
    $self->add_file( $module_filename, <<"---" ) unless $self->{filedata}{$module_filename};
package $self->{name};

our \$VERSION = '0.01';

use strict;
use warnings;

1;

__END__

=head1 NAME

$self->{name}

=cut
---

  $self->add_file( 't/basic.t', <<"---" ) unless $self->{filedata}{'t/basic.t'};
use Test::More tests => 1;
use strict;

use $self->{name};
ok( 1 );
---

  } else {
    $self->add_file( $module_filename, <<"---" ) unless $self->{filedata}{$module_filename};
package $self->{name};

use base qw( Exporter DynaLoader );

our \$VERSION = '0.01';
our \@EXPORT_OK = qw( ok );

bootstrap $self->{name} \$VERSION;

1;
---

    my $xs_filename =
      join( '/', ('lib', split(/::/, $self->{name})) ) . '.xs';
    $self->add_file( $xs_filename, <<"---" ) unless $self->{filedata}{$xs_filename};
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

MODULE = $self->{name}         PACKAGE = $self->{name}

SV *
ok()
    CODE:
        RETVAL = newSVpv( "ok", 0 );
    OUTPUT:
        RETVAL
---

  $self->add_file( 't/basic.t', <<"---" ) unless $self->{filedata}{'t/basic.t'};
use Test::More tests => 2;
use strict;

use $self->{name};
ok( 1 );

ok( $self->{name}::ok() eq 'ok' );
---
  }
}

sub _gen_manifest {
  my $self     = shift;
  my $manifest = shift;

  open( my $fh, ">$manifest" ) or do {
    $self->remove();
    die "Can't write '$manifest'\n";
  };
  print $fh join( "\n", sort keys( %{$self->{filedata}} ) );
  print $fh "\n";
  close( $fh );

}

sub name { shift()->{name} }

sub dirname {
  my $self = shift;
  my $dist = join( '-', split( /::/, $self->{name} ) );
  return File::Spec->catdir( $self->{dir}, $dist );
}

sub _real_filename {
  my $self = shift;
  my $filename = shift;
  return File::Spec->catfile( split( /\//, $filename ) );
}

sub regen {
  my $self = shift;
  my %opts = @_;

  my $dist_dirname = $self->dirname;

  if ( $opts{clean} ) {
    $self->clean() if -d $dist_dirname;
  } else {
    # TODO: This might leave dangling directories. Eg if the removed file
    # is 'lib/Simple/Simon.pm', The directory 'lib/Simple' will be left
    # even if there are no files left in it. However, clean() will remove it.
    my @files = keys %{$self->{pending}{remove}};
    foreach my $file ( @files ) {
      my $real_filename = $self->_real_filename( $file );
      my $fullname = File::Spec->catfile( $dist_dirname, $real_filename );
      unlink( $fullname ) or die "Couldn't unlink '$file'\n";
      print "Unlinking pending file '$file'\n" if $VERBOSE;
      delete( $self->{pending}{remove}{$file} );
    }
  }

  foreach my $file ( keys( %{$self->{filedata}} ) ) {
    my $real_filename = $self->_real_filename( $file );
    my $fullname = File::Spec->catfile( $dist_dirname, $real_filename );

    if ( ! -e $fullname ||
	 ( -e $fullname && $self->{pending}{change}{$file} ) ) {

      print "Changed file '$file'.\n" if $VERBOSE;

      my $dirname = File::Basename::dirname( $fullname );
      unless ( -d $dirname ) {
        File::Path::mkpath( $dirname ) or do {
          $self->remove();
          die "Can't create '$dirname'\n";
        };
      }

      if ( -e $fullname ) {
        unlink( $fullname ) or die "Can't unlink '$file'\n";
      }

      open( my $fh, ">$fullname" ) or do {
        $self->remove();
        die "Can't write '$fullname'\n";
      };
      print $fh $self->{filedata}{$file};
      close( $fh );
    }

    delete( $self->{pending}{change}{$file} );
  }

  my $manifest = File::Spec->catfile( $dist_dirname, 'MANIFEST' );
  unless ( $self->{skip_manifest} ) {
    if ( -e $manifest ) {
      unlink( $manifest ) or die "Can't remove '$manifest'\n";
    }
    $self->_gen_manifest( $manifest );
  }
}

sub clean {
  my $self = shift;

  my $here  = Cwd::abs_path();
  my $there = File::Spec->rel2abs( $self->dirname() );
  if ( -d $there ) {
    chdir( $there ) or die "Can't change directory to '$there'\n";
  } else {
    die "Distribution not found in '$there'\n";
  }

  my %names;
  foreach my $file ( keys %{$self->{filedata}} ) {
    my $filename = $self->_real_filename( $file );
    my $dirname = File::Basename::dirname( $filename );

    $names{files}{$filename} = 0;

    my @dirs = File::Spec->splitdir( $dirname );
    while ( @dirs ) {
      my $dir = File::Spec->catdir( @dirs );
      $names{dirs}{$dir} = 0;
      pop( @dirs );
    }
  }

  File::Find::finddepth( sub {
    my $dir  = File::Spec->canonpath( $File::Find::dir  );
    my $name = File::Spec->canonpath( $File::Find::name );

    if ( -d && not exists $names{dirs}{$name} ) {
      print "Removing directory '$name'\n" if $VERBOSE;
      File::Path::rmtree( $_ );
      return;
    } elsif ( -d ) {
      return;
    } elsif ( exists $names{files}{$name} ) {
      #print "Leaving file '$name'\n" if $VERBOSE;
    } else {
      print "Unlinking file '$name'\n" if $VERBOSE;
      unlink( $_ );
    }
  }, File::Spec->curdir );

  chdir( $here );
}

sub remove {
  my $self = shift;
  File::Path::rmtree( $self->dirname );
}

sub revert {
  my $self = shift;
  die "Unimplemented.\n";
}

sub add_file {
  my $self = shift;
  $self->change_file( @_ );
}

sub remove_file {
  my $self = shift;
  my $file = shift;
  unless ( exists $self->{filedata}{$file} ) {
    warn "Can't remove '$file': It does not exist.\n" if $VERBOSE;
  }
  delete( $self->{filedata}{$file} );
  $self->{pending}{remove}{$file} = 1;
}

sub change_file {
  my $self = shift;
  my $file = shift;
  my $data = shift;
  $self->{filedata}{$file} = $data;
  $self->{pending}{change}{$file} = 1;
}

1;

__END__


=head1 NAME

DistGen


=head1 DESCRIPTION


=head1 API


=head2 Constructor

=head3 new()

Create a new distribution generator. Does not actually write the
contents.

=over

=item name

The name of the module this distribution represents. The default is
'Simple'.

=item dir

The directory in which to create the distribution directory. The
default is File::Spec->curdir.

=item xs_module

Generates an XS based module.

=back


=head2 Manipulating the Distribution

=head3 regen( [OPTIONS] )

Regenerate all files that are missing or that have changed. If the
optional C<clean> argument is given, it also removes any extraneous
files that do not belong to the distribution.

=over

=item clean

When true, removes any files not part of the distribution while
regenerating.

=back

=head3 clean()

Removes any files that are not part of the distribution.

=head3 revert( [$filename] )

[Unimplemented] Returns the object to its initial state, or given a
$filename it returns that file to it's initial state if it is one of
the built-in files.

=head3 remove()

Removes the complete distribution.


=head2 Editing Files

Note that all ${filename}s should be specified with unix-style paths,
and are relative to the distribution root directory. Eg 'lib/Module.pm'

=head3 add_file( $filename, $content )

Add a $filename containg $content to the distribution. No action is
performed until the distribution is regenerated.

=head3 remove_file( $filename )

Removes $filename from the distribution. No action is performed until
the distribution is regenerated.

=head3 change_file( $filename, $content )

Changes the contents of $filename to $content. No action is performed
until the distribution is regenerated.


=head2 Properties

=head3 name()

Returns the name of the distribution.

=head3 dirname()

Returns the directory name where the distribution is created.

=cut
