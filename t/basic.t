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
  local *SAVEOUT;
  open SAVEOUT, ">&STDOUT" or die "Can't save STDOUT handle: $!";
  open STDOUT, "+> save_out" or die "Can't create save_out: $!";
  
  chdir 'Sample';
  my $m = new Module::Build(module_name => 'Sample', verbose => 1);
  eval {$m->dispatch('test')};
  
  close STDOUT;
  open STDOUT, ">&SAVEOUT" or die "Can't restore STDOUT: $!";
  
  my @dirs = File::Spec->splitdir($m->cwd); pop @dirs;
  my $t_dir = File::Spec->catdir(@dirs);
  chdir $t_dir or die "Can't change back to $t_dir: $!";
  open my($fh), "< save_out" or die "Can't read save_out: $!";
  my $output = join '', <$fh>;

  ok $@, '';
  ok uc($output), '/OK 1/';  # Use uc() so we don't confuse the current test output

  $m->dispatch('realclean');
}
