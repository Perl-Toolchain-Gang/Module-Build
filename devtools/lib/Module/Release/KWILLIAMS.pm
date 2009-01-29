package Module::Release::KWILLIAMS;

use strict;
use Module::Release;
our @ISA = qw(Module::Release);

sub make_cvs_tag {
  # Not used much anymore, since most of my stuff has transitioned to SVN
  my $self = shift;
  (my $version) = $self->{remote} =~ / - (\d[\w.]*) \.tar \.gz $/x;
  $version =~ s/[^a-z0-9_]/_/gi;
  return "release-$version";
}

sub new {
  my $class = shift;
  my %args = -e 'Build.PL'
    ? (make => 'Build',
       'Makefile.PL' => 'Build.PL',
       'Makefile' => 'Build')
    : ();

  $class->check_changes_file;
  $class->check_manifest;
  
  return $class->SUPER::new( %args, $class->get_pause_passwd, @_ );
}

sub get_pause_passwd {
  # Gets my PAUSE password from my keychain
  my $self = shift;
  if (`security find-internet-password -s pause.perl.org -g 2>&1` =~ /^password: "(.*)"/m) {
    return (cpan_pass => $1);
  }
  return();
}

sub check_changes_file {
  # This doesn't really do anything anymore
  my $self = shift;
  my $version = qr{\d+\.[\d_]+};
  my $date = qr{\w+\s+ \w+\s+ \d+\s+ \d+ : \d+ : \d+\s+ \w+\s+ \d+}x;

  open my($fh), 'Changes' or die "Can't read Changes: $!";
  local $_;
  while (<$fh>) {
    next unless /^$version/;
#    die "Looks like there's no timestamp on version line in Changes:\n$_"
#      unless /^$version\s+(\(.*?\))?\s*$date/;
    last;
  }
}

sub check_manifest {
  require ExtUtils::Manifest;
  die "Extra files found not mentioned in MANIFEST"
    if ExtUtils::Manifest::filecheck();
}

1;
