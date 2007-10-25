#!/usr/bin/perl

# A script to check a local copy of M::B against bleadperl, generating
# a blead patch if they're out of sync.  An optional directory
# argument will be chdir()-ed into before comparing.

# There are still a couple of holes here that need plugging, though.

use strict;
chdir shift() if @ARGV;

my $bleadstart = "~/Downloads/perl/bleadperl/lib/Module/Build";

diff("$bleadstart.pm", "lib/Module/Build.pm" );

diff($bleadstart, "lib/Module/Build",
     qw(t Changes));

diff("$bleadstart/Changes", "Changes" );

diff("$bleadstart/t", "t" );

######################
sub diff {
  my ($first, $second, @skip) = @_;
  local $_ = `diff -ur $first $second`;

  s/^Only in .*~\n//mg;

  for my $x (@skip) {
    s/^Only in .* $x\n//m;
  }
  print unless defined wantarray;
  return $_;
}
