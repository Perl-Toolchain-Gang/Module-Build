######################### We start with some black magic to print on failure.

use Test;
BEGIN { plan tests => 4 }
use Module::Build;
ok(1);

######################### End of black magic.

# Test object creation
{
  my $build = new Module::Build
    (
     module_name => 'Module::Build',
    );
  ok $build;
}

# Test prerequisite checking
{
  local @INC = (@INC, 't/lib');
  my $flagged = 0;
  local $SIG{__WARN__} = sub { $flagged = 1 if $_[0] =~ /ModuleBuildOne/};
  my $build = new Module::Build
    (
     module_name => 'Module::Build',
     requires => {ModuleBuildOne => 0},
    );
  ok $flagged, 0;
}

{
  local @INC = (@INC, 't/lib');
  my $flagged = 0;
  local $SIG{__WARN__} = sub { $flagged = 1 if $_[0] =~ /ModuleBuildOne/};
  my $build = new Module::Build
    (
     module_name => 'Module::Build',
     requires => {ModuleBuildOne => 3},
    );
  ok $flagged, 1;
}
