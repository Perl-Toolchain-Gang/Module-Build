package Module::Build::Base;

use strict;
use Config;

sub new {
  my ($package) = @_;
  return bless {
		build_file => 'Build',
		build_package => $package,
	       }, $package;
}  

sub create {
  my ($self, %args) = @_;

  if (-e $self->{build_file}) {
    print "Removing previous file '$self->{build_file}'\n";
    unlink $self->{build_file} or die "Couldn't remove '$self->{build_file}': $!";
  }
  
  print "Creating new '$self->{build_file}' file\n";
  local *FH;
  open FH, ">$self->{build_file}" or die "Can't create '$self->{build_file}': $!";

  my $quoted_INC = join ', ', map "'$_'", @INC;

  print FH <<EOF;
$Config{startperl}

BEGIN { \@INC = ($quoted_INC) }

use $self->{build_package};

my \$build = new $self->{build_package};
\$build->dispatch(\@ARGV);

EOF
  close FH;

  chmod 0544, $self->{build_file};

  return 1;
}


sub dispatch {
  my ($self, @args) = @_;
  print ref($self), "->dispatch(@args) called\n";
}


1;
__END__


=head1 NAME

Module::Build - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Module::Build;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Module::Build, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.


=head1 AUTHOR

Ken Williams, ken@forum.swarthmore.edu

=head1 SEE ALSO

perl(1), ExtUtils::MakeMaker(3)

=cut
