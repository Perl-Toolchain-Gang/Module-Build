######################### We start with some black magic to print on failure.

use Test;
BEGIN { plan tests => 4 }
use Module::Build;
ok(1);

######################### End of black magic.

chdir 't';

# Test object creation
{
  my $build = new Module::Build
    (
     module_name => 'ModuleBuildOne',
    );
  ok $build;
}

# Test prerequisite checking
{
  local @INC = (@INC, 'lib');
  my $flagged = 0;
  local $SIG{__WARN__} = sub { $flagged = 1 if $_[0] =~ /ModuleBuildOne/};
  new Module::Build
    (
     module_name => 'ModuleBuildOne',
     requires => {ModuleBuildOne => 0},
    )->dispatch('realclean');
  ok $flagged, 0;

  $flagged = 0;
  new Module::Build
    (
     module_name => 'ModuleBuildOne',
     requires => {ModuleBuildOne => 3},
    )->dispatch('realclean');
  ok $flagged, 1;
}

