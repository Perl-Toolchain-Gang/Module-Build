######################### We start with some black magic to print on failure.

use Test;
BEGIN { plan tests => 11 }
use Module::Build;
ok(1);

use File::Spec;

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
  my $m = new Module::Build
    (
     module_name => 'ModuleBuildOne',
     requires => {ModuleBuildOne => 0},
    );
  ok $flagged, 0;
  ok !$m->prereq_failures;
  $m->dispatch('realclean');

  $flagged = 0;
  $m = new Module::Build
    (
     module_name => 'ModuleBuildOne',
     requires => {ModuleBuildOne => 3},
    );
  ok $flagged, 1;
  ok $m->prereq_failures;
  ok $m->prereq_failures->{requires}{ModuleBuildOne};
  ok $m->prereq_failures->{requires}{ModuleBuildOne}{have}, 0.01;
  ok $m->prereq_failures->{requires}{ModuleBuildOne}{need}, 3;

  $m->dispatch('realclean');
}

# Test verbosity
{
  require Cwd;
  my $cwd = Cwd::cwd();

  chdir 'Sample';
  my $m = new Module::Build(module_name => 'Sample');

  # Use uc() so we don't confuse the current test output
  ok uc(stdout_of( sub {$m->dispatch('test', verbose => 1)} )), '/OK 1/';
  ok uc(stdout_of( sub {$m->dispatch('test', verbose => 0)} )), '/\.\.OK/';
  
  $m->dispatch('realclean');
  chdir $cwd or die "Can't change back to $cwd: $!";
}

sub stdout_of {
  my $subr = shift;
  my $outfile = 'save_out';

  local *SAVEOUT;
  open SAVEOUT, ">&STDOUT" or die "Can't save STDOUT handle: $!";
  open STDOUT, "> $outfile" or die "Can't create $outfile: $!";

  $subr->();

  open STDOUT, ">&SAVEOUT" or die "Can't restore STDOUT: $!";
  return slurp($outfile);
}

sub slurp {
  open my($fh), $_[0] or die "Can't open $_[0]: $!";
  local $/;
  return <$fh>;
};
