
sub stdout_of {
  my $subr = shift;
  my $outfile = 'save_out';

  local *SAVEOUT;
  open SAVEOUT, ">&STDOUT" or die "Can't save STDOUT handle: $!";
  open STDOUT, "> $outfile" or die "Can't create $outfile: $!";

  eval {$subr->()};
  open STDOUT, ">&SAVEOUT" or die "Can't restore STDOUT: $!";
#  die $@ if $@;

  return slurp($outfile);
}

sub slurp {
  my $fh = IO::File->new($_[0]) or die "Can't open $_[0]: $!";
  local $/;
  return <$fh>;
}

1;
