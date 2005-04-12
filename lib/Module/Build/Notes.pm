package Module::Build::Notes;

# A class for persistent hashes

use strict;
use Data::Dumper;
use IO::File;

use Carp; BEGIN{ $SIG{__DIE__} = \&carp::confess }

sub new {
  my ($class, %args) = @_;
  my $file = delete $args{file} or die "Missing required parameter 'file' to new()";
  my $self = bless {
		    disk => {},
		    new  => {},
		    file => $file,
		    %args,
		   }, $class;
}

sub restore {
  my $self = shift;

  my $fh = IO::File->new("< $self->{file}") or die "Can't read $self->{file}: $!";
  $self->{disk} = eval do {local $/; <$fh>};
  die $@ if $@;
  $self->{new} = {};
}

sub access {
  my $self = shift;
  return $self->read() unless @_;
  
  my $key = shift;
  return $self->read($key) unless @_;
  
  my $value = shift;
  return $self->write({ $key => $value });
}

sub has_data {
  my $self = shift;
  return keys %{$self->read()} > 0;
}

sub exists {
  my ($self, $key) = @_;
  return exists($self->{new}{$key}) || exists($self->{disk}{$key});
}

sub read {
  my $self = shift;

  if (@_) {
    # Return 1 key as a scalar
    my $key = shift;
    return $self->{new}{$key} if exists $self->{new}{$key};
    return $self->{disk}{$key};
  }
   
  # Return all data
  my $out = (keys %{$self->{new}}
	     ? {%{$self->{disk}}, %{$self->{new}}}
	     : $self->{disk});
  return wantarray ? %$out : $out;
}

sub write {
  my ($self, $href) = @_;
  $href ||= {};
  
  @{$self->{new}}{ keys %$href } = values %$href;  # Merge

  # Do some optimization to avoid unnecessary writes
  foreach my $key (keys %{ $self->{new} }) {
    next if ref $self->{new}{$key};
    next if ref $self->{disk}{$key} or !exists $self->{disk}{$key};
    delete $self->{new}{$key} if $self->{new}{$key} eq $self->{disk}{$key};
  }
  
  if (my $file = $self->{file}) {
    my ($vol, $dir, $base) = File::Spec->splitpath($file);
    $dir = File::Spec->catpath($vol, $dir, '');
    return unless -e $dir && -d $dir;  # The user needs to arrange for this

    return if -e $file and !keys %{ $self->{new} };  # Nothing to do
    
    @{$self->{disk}}{ keys %{$self->{new}} } = values %{$self->{new}};  # Merge 
    $self->_dump($file, $self->{disk});
   
    $self->{new} = {};
  }
  return $self->read;
}

sub _dump {
  my ($self, $file, $data) = @_;
  
  my $fh = IO::File->new("> $file") or die "Can't create '$file': $!";
  local $Data::Dumper::Terse = 1;
  print $fh Data::Dumper::Dumper($data);
}

sub write_config_data {
  my ($self, %args) = @_;

  # XXX need to handle auto_features

  my $fh = IO::File->new("> $args{file}") or die "Can't create '$args{file}': $!";

  printf $fh <<'EOF', $args{config_module};
package %s;
use strict;
my $arrayref = eval do {local $/; <DATA>}
  or die "Couldn't load ConfigData data: $@";
close DATA;
my ($config, $features) = @$arrayref;

sub config { $config->{$_[1]} }
sub feature { $features->{$_[1]} }

sub set_config { $config->{$_[1]} = $_[2] }
sub set_feature { $features->{$_[1]} = 0+!!$_[2] }

sub feature_names { keys %%$features }
sub config_names  { keys %%$config }

sub write {
  my $me = __FILE__;
  require IO::File;
  require Data::Dumper;

  my $mode_orig = (stat $me)[2] & 07777;
  chmod($mode_orig | 0222, $me); # Make it writeable
  my $fh = IO::File->new($me, 'r+') or die "Can't rewrite $me: $!";
  seek($fh, 0, 0);
  while (<$fh>) {
    last if /^__DATA__$/;
  }
  die "Couldn't find __DATA__ token in $me" if eof($fh);

  local $Data::Dumper::Terse = 1;
  seek($fh, tell($fh), 0);
  $fh->print( Data::Dumper::Dumper([$config, $features]) );
  truncate($fh, tell($fh));
  $fh->close;

  chmod($mode_orig, $me)
    or warn "Couldn't restore permissions on $me: $!";
}

EOF

  my ($module_name, $notes_name) = ($args{module}, $args{config_module});
  printf $fh <<"EOF", $notes_name, $module_name;

=head1 NAME

$notes_name - Configuration for $module_name

=head1 SYNOPSIS

  use $notes_name;
  \$value = $notes_name->config('foo');
  \$value = $notes_name->feature('bar');
  
  \@names = $notes_name->config_names;
  \@names = $notes_name->feature_names;
  
  $notes_name->set_config(foo => \$new_value);
  $notes_name->set_feature(bar => \$new_value);
  $notes_name->write;  # Save changes

=head1 DESCRIPTION

This module holds the configuration data for the C<$module_name>
module.  It also provides a programmatic interface for getting or
setting that configuration data.  Note that in order to actually make
changes, you'll have to have write access to the C<$notes_name>
module, and you should attempt to understand the repercussions of your
actions.

=head1 METHODS

=over 4

=item config(\$name)

Given a string argument, returns the value of the configuration item
by that name, or C<undef> if no such item exists.

=item feature(\$name)

Given a string argument, returns the value of the feature by that
name, or C<undef> if no such feature exists.

=item set_config(\$name, \$value)

Sets the configuration item with the given name to the given value.
The value may be any Perl scalar that will serialize correctly using
C<Data::Dumper>.  This includes references, objects (usually), and
complex data structures.  It probably does not include transient
things like filehandles or sockets.

=item set_feature(\$name, \$value)

Sets the feature with the given name to the given boolean value.  The
value will be converted to 0 or 1 automatically.

=item config_names()

Returns a list of all the names of config items currently defined in
C<$notes_name>, or in scalar context the number of items.

=item feature_names()

Returns a list of all the names of features currently defined in
C<$notes_name>, or in scalar context the number of features.

=item write()

Commits any changes from C<set_config()> and C<set_feature()> to disk.
Requires write access to the C<$notes_name> module.

=back

=head1 AUTHOR

C<$notes_name> was automatically created using C<Module::Build>.
C<Module::Build> was written by Ken Williams, but he holds no
authorship claim or copyright claim to the contents of C<$notes_name>.

=cut

__DATA__

EOF

  local $Data::Dumper::Terse = 1;
  print $fh Data::Dumper::Dumper([$args{config_data}, $args{feature}]);
}

1;
