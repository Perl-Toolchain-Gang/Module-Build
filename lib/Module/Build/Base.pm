package Module::Build::Base;

# $Id$

use strict;
use Config;
use File::Copy ();
use File::Find ();
use File::Path ();
use File::Basename ();
use File::Spec ();
use File::Compare ();
use Data::Dumper ();

sub new {
  my $package = shift;
  my %input = @_;

  my $args   = delete $input{args}   || {};
  my $config = delete $input{config} || {};

  my ($action, $cmd_args) = __PACKAGE__->cull_args(@ARGV);
  die "Too early to specify a build action '$action'.  Do 'Build $action' instead.\n"
    if $action;

  my $cmd_config;
  if ($cmd_args->{config}) {
    # XXX need to hashify this string better (deal with quoted whitespace)
    $cmd_config->{$1} = $2 while $cmd_args->{config} =~ /(\w+)=(\S+)/g;
  } else {
    $cmd_config = {};
  }
  delete $cmd_args->{config};

  # Extract our 'properties' from $cmd_args, the rest are put in 'args'
  my $cmd_properties = {};
  foreach my $key (keys %$cmd_args) {
    $cmd_properties->{$key} = delete $cmd_args->{$key} if __PACKAGE__->valid_property($key);
  }

  # 'args' are arbitrary user args.
  # 'config' is Config.pm and its overridden values.
  # 'properties' is stuff Module::Build needs in order to work.  They get saved in _build/.
  # Anything else in $self doesn't get saved.

  my $self = bless {
		    args => {%$args, %$cmd_args},
		    config => {%Config, %$config, %$cmd_config},
		    properties => {
				   build_script => 'Build',
				   base_dir => $package->cwd,
				   config_dir => '_build',
				   requires => {},
				   recommends => {},
				   build_requires => {},
				   conflicts => {},
				   PL_files => {},
				   scripts => [],
				   %input,
				   %$cmd_properties,
				  },
		   }, $package;
  my $p = $self->{properties};

  # Synonyms
  $p->{requires} = delete $p->{prereq} if exists $p->{prereq};

  # Shortcuts
  if (exists $p->{module_name}) {
    ($p->{dist_name} = $p->{module_name}) =~ s/::/-/g
      unless exists $p->{dist_name};
    $p->{dist_version_from} = join( '/', 'lib', split '::', $p->{module_name} ) . '.pm'
      unless exists $p->{dist_version_from} or exists $p->{dist_version};
  }

  $self->check_manifest;
  $self->check_prereq;
  $self->find_version;
  
  return $self;
}

sub cwd {
  require Cwd;
  return Cwd::cwd;
}

sub base_dir { shift()->{properties}{base_dir} }

sub prompt {
  my $self = shift;
  my ($mess, $def) = @_;
  die "prompt() called without a prompt message" unless @_;

  my $INTERACTIVE = -t STDIN && (-t STDOUT || !(-f STDOUT || -c STDOUT)) ;   # Pipe?
  
  ($def, my $dispdef) = defined $def ? ($def, "[$def] ") : ('', ' ');

  {
    local $|=1;
    print "$mess $dispdef";
  }
  my $ans;
  if ($INTERACTIVE) {
    $ans = <STDIN>;
    if ( defined $ans ) {
      chomp $ans;
    } else { # user hit ctrl-D
      print "\n";
    }
  }
  
  unless (defined($ans) and length($ans)) {
    print "$def\n";
    $ans = $def;
  }
  
  return $ans;
}

sub y_n {
  my $self = shift;
  die "y_n() called without a prompt message" unless @_;
  
  my $answer;
  while (1) {
    $answer = $self->prompt(@_);
    return 1 if $answer =~ /^y/i;
    return 0 if $answer =~ /^n/i;
    print "Please answer 'y' or 'n'.\n";
  }
}

sub resume {
  my $package = shift;
  my $self = bless {@_}, $package;
  
  $self->read_config;
  return $self;
}

{
  # XXX huge hack alert - will revisit this later
  my %valid_properties = map {$_ => 1}
    qw(
       module_name
       dist_name
       dist_version
       dist_version_from
       requires
       recommends
       PL_files
       scripts
       config_dir
       build_script
       debugger
       verbose
       c_source
       autosplit
      );

  sub valid_property { exists $valid_properties{$_[1]} }
}

# XXX Problem - if Module::Build is loaded from a different directory,
# it'll look for (and perhaps destroy/create) a _build directory.
sub subclass {
  my ($pack, %opts) = @_;

  my $build_dir = '_build'; # XXX The _build directory is ostensibly settable by the user.  Shouldn't hard-code here.
  $pack->delete_filetree($build_dir) if -e $build_dir;

  die "Must provide 'code' or 'class' option to subclass()\n"
    unless $opts{code} or $opts{class};

  $opts{code}  ||= '';
  $opts{class} ||= 'MyModuleBuilder';
  
  my $filename = File::Spec->catfile($build_dir, 'lib', split '::', $opts{class}) . '.pm';
  my $filedir  = File::Basename::dirname($filename);
  print "Creating custom builder $filename in $filedir\n";
  
  File::Path::mkpath($filedir);
  die "Can't create directory $filedir: $!" unless -d $filedir;
  
  open my($fh), ">$filename" or die "Can't create $filename: $!";
  print $fh <<EOF;
package $opts{class};
use Module::Build;
\@ISA = qw(Module::Build);
$opts{code}
1;
EOF
  close $fh;
  
  push @INC, File::Spec->catdir($build_dir, 'lib');
  eval "use $opts{class}";
  die $@ if $@;

  return $opts{class};
}

sub find_version {
  my ($self) = @_;
  my $p = $self->{properties};

  return if exists $p->{dist_version};
  
  my $version_from;
  if (exists $p->{dist_version_from}) {
    # dist_version_from is always a Unix-style path
    $version_from = File::Spec->catfile( split '/', $p->{dist_version_from} );
  } else {
    die "Must supply either 'dist_version', 'dist_version_from', or 'module_name' parameter";
  }

  $p->{dist_version} = $self->version_from_file($version_from);
}

sub find_module_by_name {
  my ($self, $mod, $dirs) = @_;
  my $file = File::Spec->catfile(split '::', $mod);
  foreach (@$dirs) {
    my $testfile = File::Spec->catfile($_, $file);
    return $testfile if -e $testfile and !-d _;  # For stuff like ExtUtils::xsubpp
    return "$testfile.pm" if -e "$testfile.pm";
  }
  return;
}

sub version_from_file {
  my ($self, $file) = @_;

  # Some of this code came from the ExtUtils:: hierarchy.
  open my($fh), $file or die "Can't open '$file' for version: $!";
  while (<$fh>) {
    if ( my ($sigil, $var) = /([\$*])(([\w\:\']*)\bVERSION)\b.*\=/ ) {
      my $eval = qq{
		    package Module::Build::Base::_version;
		    no strict;
		    
		    local $sigil$var;
		    \$$var=undef; do {
		      $_
		    }; \$$var
		   };
      local $^W;
      return scalar eval $eval;
    }
  }
  return undef;
}

sub add_to_cleanup {
  my $self = shift;
  my @need_to_write = grep {!exists $self->{cleanup}{$_}} @_;
  return unless @need_to_write;
  
  if ( my $file = $self->config_file('cleanup') ) {
    open my($fh), ">> $file" or die "Can't append to $file: $!";
    print $fh "$_\n" foreach @need_to_write;
  }
  
  @{$self->{cleanup}}{ @need_to_write } = ();
}

sub config_file {
  my $self = shift;
  return unless -d $self->{properties}{config_dir};
  return File::Spec->catfile($self->{properties}{config_dir}, @_);
}

sub read_config {
  my ($self) = @_;
  
  my $file = $self->config_file('build_params');
  open my $fh, $file or die "Can't read '$file': $!";
  my $ref = eval do {local $/; <$fh>};
  die if $@;
  ($self->{args}, $self->{config}, $self->{properties}) = @$ref;
  close $fh;
  
  my $cleanup_file = $self->config_file('cleanup');
  $self->{cleanup} = {};
  if (-e $cleanup_file) {
    open my $fh, $cleanup_file or die "Can't read '$file': $!";
    my @files = <$fh>;
    chomp @files;
    @{$self->{cleanup}}{@files} = ();
  }
}

sub write_config {
  my ($self) = @_;
  
  File::Path::mkpath($self->{properties}{config_dir});
  -d $self->{properties}{config_dir} or die "Can't mkdir $self->{properties}{config_dir}: $!";
  
  local $Data::Dumper::Terse = 1;

  my $file = $self->config_file('build_params');
  open my $fh, "> $file" or die "Can't create '$file': $!";
  print $fh Data::Dumper::Dumper([$self->{args}, $self->{config}, $self->{properties}]);
  close $fh;

  $file = $self->config_file('prereqs');
  open $fh, "> $file" or die "Can't create '$file': $!";
  my @items = qw(requires build_requires conflicts recommends);
  print $fh Data::Dumper::Dumper( { map {$_,$self->{properties}{$_}} @items } );
  close $fh;
}

sub prereq_failures {
  my $self = shift;

  my @types = qw(requires recommends build_requires conflicts);
  my $out;

  foreach my $type (@types) {
    while (my ($modname, $spec) = each %{$self->{properties}{$type}}) {
      my $status = $self->check_installed_status($modname, $spec);
      
      if ($type eq 'conflicts') {
	next if !$status->{ok};
	$status->{conflicts} = delete $status->{need};
	$status->{message} = "Installed version '$status->{have}' of $modname conflicts with this distribution";
      } else {
	next if $status->{ok};
      }

      $out->{$type}{$modname} = $status;
    }
  }

  return $out;
}

sub check_prereq {
  my $self = shift;

  my $failures = $self->prereq_failures;
  return 1 unless $failures;
  
  foreach my $type (qw(requires build_requires conflicts recommends)) {
    next unless $failures->{$type};
    my $prefix = $type eq 'recommends' ? 'WARNING' : 'ERROR';
    while (my ($module, $status) = each %{$failures->{$type}}) {
      warn "$prefix: $module: $status->{message}\n";
    }
  }
  
  warn "ERRORS/WARNINGS FOUND IN PREREQUISITES.  You may wish to install the versions\n".
       " of the modules indicated above before proceeding with this installation.\n\n";
  return 0;
}

sub perl_version_to_float {
  my ($self, $version) = @_;
  $version =~ s/\./../;
  $version =~ s/\.(\d+)/sprintf '%03d', $1/eg;
  return $version;
}

sub check_installed_status {
  my ($self, $modname, $spec) = @_;
  my %status = (need => $spec);
  
  if ($modname eq 'perl') {
    # Check the current perl interpreter
    # It's much more convenient to use $] here than $^V, but 'man
    # perlvar' says I'm not supposed to.  Bloody tyrant.
    $status{have} = $^V ? $self->perl_version_to_float(sprintf "%vd", $^V) : $];
    
  } else {
    my $file = $self->find_module_by_name($modname, \@INC);
    unless ($file) {
      @status{ qw(have message) } = ('<none>', "Prerequisite $modname isn't installed");
      return \%status;
    }
    
    $status{have} = $self->version_from_file($file);
    if ($spec and !$status{have}) {
      @status{ qw(have message) } = (undef, "Couldn't find a \$VERSION in prerequisite '$file'");
      return \%status;
    }
  }
  
  my @conditions;
  if ($spec =~ /^\s*([\w.]+)\s*$/) { # A plain number, maybe with dots, letters, and underscores
    @conditions = (">= $spec");
  } else {
    @conditions = split /\s*,\s*/, $self->{properties}{requires}{$modname};
  }
  
  foreach (@conditions) {
    unless ( /^\s*  (<=?|>=?|==|!=)  \s*  ([\w.]+)  \s*$/x ) {
      die "Invalid prerequisite condition '$_' for $modname";
    }
    if ($modname eq 'perl') {
      my ($op, $version) = ($1, $2);
      $_ = "$op " . $self->perl_version_to_float($version);
    }
    unless (eval "\$status{have} $_") {
      $status{message} = "Version $status{have} is installed, but we need version $_";
      return \%status;
    }
  }
  
  $status{ok} = 1;
  return \%status;
}

# I wish I could set $! to a string, but I can't, so I use $@
sub check_installed_version {
  my ($self, $modname, $spec) = @_;
  
  my $status = $self->check_installed_status($modname, $spec);
  
  if ($status->{ok}) {
    return $status->{have} if $status->{have} and $status->{have} ne '<none>';
    return '0 but true';
  }
  
  $@ = $status->{message};
  return 0;
}

sub make_executable {
  # Perl's chmod() is mapped to useful things on various non-Unix
  # platforms, so we use it in the base class even though it looks
  # Unixish.

  my $self = shift;
  foreach (@_) {
    my $current_mode = (stat $_)[2];
    chmod $current_mode | 0111, $_;
  }
}

sub print_build_script {
  my ($self, $fh) = @_;
  
  my $build_package = ref($self);

  my ($config_dir, $build_script, $base_dir) = 
    ($self->{properties}{config_dir}, $self->{properties}{build_script}, $self->base_dir);

  my @myINC = @INC;
  for ($config_dir, $build_script, $base_dir, @myINC) {
    s/([\\\'])/\\$1/g;
  }

  my $quoted_INC = join ', ', map "'$_'", @myINC;

  print $fh <<EOF;
$self->{config}{startperl} -w

BEGIN {
  chdir('$base_dir') or die 'Cannot chdir to $base_dir: '.\$!;
  \@INC = ($quoted_INC);
}

use $build_package;

# This should have just enough arguments to be able to bootstrap the rest.
my \$build = resume $build_package (
  properties => {
    config_dir => '$config_dir',
    build_script => '$build_script',
  },
);
\$build->dispatch;
EOF
}

sub create_build_script {
  my ($self) = @_;
  my $p = $self->{properties};
  
  $self->write_config;
  
  if ( $self->delete_filetree($p->{build_script}) ) {
    print "Removed previous script '$p->{build_script}'\n";
  }

  print("Creating new '$p->{build_script}' script for ",
	"'$p->{dist_name}' version '$p->{dist_version}'\n");
  open my $fh, ">$p->{build_script}" or die "Can't create '$p->{build_script}': $!";
  $self->print_build_script($fh);
  close $fh;
  
  $self->make_executable($p->{build_script});

  return 1;
}

sub check_manifest {
  # Stolen nearly verbatim from MakeMaker.  But ExtUtils::Manifest
  # could easily be re-written into a modern Perl dialect.

  print "Checking whether your kit is complete...\n";
  require ExtUtils::Manifest;  # ExtUtils::Manifest is not warnings clean.
  local ($^W, $ExtUtils::Manifest::Quiet) = (0,1);
  
  if (my @missed = ExtUtils::Manifest::manicheck()) {
    print "Warning: the following files are missing in your kit:\n";
    print "\t", join "\n\t", @missed;
    print "\n";
    print "Please inform the author.\n";
  } else {
    print "Looks good\n";
  }
}

sub dispatch {
  my $self = shift;
  
  my (%p, $args, $action);
  if (@_) {
    ($action, %p) = @_;
    $args = $p{args} ? delete($p{args}) : {};
  } else {
    ($action, $args) = $self->cull_args(@ARGV);

    # Extract our 'properties' from $args
    foreach my $key (keys %$args) {
      $p{$key} = delete $args->{$key} if __PACKAGE__->valid_property($key);
    }
  }

  $self->{action} = $action || 'build';
  $self->{args} = {%{$self->{args}}, %$args};
  $self->{properties} = {%{$self->{properties}}, %p};

  my $method = "ACTION_$self->{action}";
  print("No action '$self->{action}' defined.\n"), return unless $self->can($method);

  return $self->$method;
}

sub cull_args {
  my $self = shift;
  my ($action, %args);
  foreach (@_) {
    if ( /^(\w+)=(.*)/ ) {
      $args{$1} = $2;
    } elsif ( /^(\w+)$/ ) {
      die "Error: multiple build actions given: '$action' and '$1'" if $action;
      $action = $1;
    } else {
      die "Malformed build parameter '$_'";
    }
  }
  return ($action, \%args);
}

sub super_classes {
  my ($self, $class, $seen) = @_;
  $class ||= ref($self);
  $seen  ||= {};
  
  no strict 'refs';
  my @super = grep {not $seen->{$_}++} $class, @{ $class . '::ISA' };
  return @super, map {$self->super_classes($_,$seen)} @super;
}

sub known_actions {
  my ($self) = @_;

  my %actions;
  no strict 'refs';
  
  foreach my $class ($self->super_classes) {
    foreach ( keys %{ $class . '::' } ) {
      $actions{$1}++ if /ACTION_(\w+)/;
    }
  }

  return sort keys %actions;
}

sub ACTION_help {
  my ($self) = @_;

  print <<EOF;

 Usage: $0 <action> arg1=value arg2=value ...
 Example: $0 test verbose=1
 
 Actions defined:
EOF

  my @actions = $self->known_actions;
  # Flow down columns, not across rows
  @actions = map $actions[($_ + ($_ % 2) * @actions) / 2],  0..$#actions;
  
  while (my ($one, $two) = splice @actions, 0, 2) {
    printf("  %-12s                   %-12s\n", $one, $two||'');
  }

  print "\nSee `perldoc Module::Build` for details of the individual actions.\n";
}

sub ACTION_test {
  my ($self) = @_;
  require Test::Harness;
  
  $self->depends_on('build');
  
  # Do everything in our power to work with all versions of Test::Harness
  local ($Test::Harness::switches,
	 $Test::Harness::Switches,
         $ENV{HARNESS_PERL_SWITCHES}) = ($self->{properties}{debugger} ? '-w -d' : '') x 3;

  local ($Test::Harness::verbose,
	 $Test::Harness::Verbose,
	 $ENV{TEST_VERBOSE},
         $ENV{HARNESS_VERBOSE}) = ($self->{properties}{verbose} || 0) x 4;

  # Make sure we test the module in blib/
  local @INC = (File::Spec->catdir('blib', 'lib'),
		File::Spec->catdir('blib', 'arch'),
		@INC);
  
  # Find all possible tests and run them
  my @tests;
  if ($self->{args}{test_files}) {
    @tests = ($self->{args}{test_files});
  } else {
    push @tests, 'test.pl'                          if -e 'test.pl';
    push @tests, @{$self->rscan_dir('t', qr{\.t$})} if -e 't' and -d _;
  }
  if (@tests) {
    # Work around a Test::Harness bug that loses the particular perl we're running under
    local $^X = $self->{config}{perlpath} unless $Test::Harness::VERSION gt '2.01';
    Test::Harness::runtests(sort @tests);
  } else {
    print("No tests defined.\n");
  }

  # This will get run and the user will see the output.  It doesn't
  # emit Test::Harness-style output.
  if (-e 'visual.pl') {
    $self->run_perl_script('visual.pl', '-Mblib');
  }
}

sub ACTION_testdb {
  my ($self) = @_;
  local $self->{properties}{debugger} = 1;
  $self->depends_on('test');
}

sub compile_support_files {
  my $self = shift;

  if ($self->{properties}{c_source}) {
    $self->process_PL_files($self->{properties}{c_source});
    
    my $files = $self->rscan_dir($self->{properties}{c_source}, qr{\.c(pp)?$});
    
    push @{$self->{include_dirs}}, $self->{properties}{c_source};

    foreach my $file (@$files) {
      push @{$self->{objects}}, $self->compile_c($file);
    }
  }
}

sub ACTION_build {
  my ($self) = @_;

  $self->compile_support_files;
  
  # What more needs to be done when creating blib/ from lib/?
  # Currently we handle .pm, .xs, .pod, and .PL files.

  $self->process_PL_files('lib');

  my $blib = 'blib';
  $self->add_to_cleanup($blib);
  File::Path::mkpath($blib);
  
  my $files = $self->rscan_dir('lib', qr{\.(pm|pod|xs)$});
  $self->lib_to_blib($files, $blib);
  
  if (@{$self->{properties}{scripts}}) {
    my $script_dir = File::Spec->catdir($blib, 'script');
    File::Path::mkpath( $script_dir );

    foreach my $file (@{$self->{properties}{scripts}}) {
      my $result = $self->copy_if_modified($file, $script_dir, 'flatten');
      $self->make_executable($result) if $result;
    }
  }

}

sub ACTION_manifypods {
  my $self = shift;
  require Pod::Man;
  
  my $p = Pod::Man->new(section => 3);
  my $files = $self->rscan_dir('lib', qr{\.(pm|pod)$});
  foreach my $file (@$files) {
    my @path = File::Spec->splitdir($file);
    # ...
  }
}

# For systems that don't have 'diff' executable, should use Algorithm::Diff
sub ACTION_diff {
  my $self = shift;
  $self->depends_on('build');
  my @myINC = grep {$_ ne 'lib'} @INC;
  my @flags = $self->split_like_shell($self->{args}{flags} || '');
  
  my $installmap = $self->install_map('blib');
  delete $installmap->{read};

  my $text_suffix = qr{\.(pm|pod)$};

  while (my $localdir = each %$installmap) {
    my $files = $self->rscan_dir($localdir, sub {-f});
    
    foreach my $file (@$files) {
      my @parts = File::Spec->splitdir($file);
      my @localparts = File::Spec->splitdir($localdir);
      @parts = @parts[@localparts .. $#parts]; # Get rid of blib/lib or similar
      
      my $installed = $self->find_module_by_name(join('::', @parts), \@myINC);
      if (not $installed) {
	print "Only in lib: $file\n";
	next;
      }
      
      my $status = File::Compare::compare($installed, $file);
      next if $status == 0;  # Files are the same
      die "Can't compare $installed and $file: $!" if $status == -1;
      
      if ($file !~ /$text_suffix/) {
	print "Binary files $file and $installed differ\n";
      } else {
	$self->do_system('diff', @flags, $installed, $file);
      }
    }
  }
}

sub process_PL_files {
  my ($self, $dir) = @_;
  my $p = $self->{properties}{PL_files};
  my $files = $self->rscan_dir($dir, qr{\.PL$});
  foreach my $file (@$files) {
    my @to = (exists $p->{$file} ?
	      (ref $p->{$file} ? @{$p->{$file}} : ($p->{$file})) :
	      $file =~ /^(.*)\.PL$/);
    
    if (grep {!-e $_ or  -M _ > -M $file} @to) {
      $self->run_perl_script($file);
      $self->add_to_cleanup(@to);
    }
  }
}

sub ACTION_install {
  my ($self) = @_;
  require ExtUtils::Install;
  $self->depends_on('build');
  ExtUtils::Install::install($self->install_map('blib'), 1, 0, $self->{args}{uninst}||0);
}

sub ACTION_fakeinstall {
  my ($self) = @_;
  require ExtUtils::Install;
  $self->depends_on('build');
  ExtUtils::Install::install($self->install_map('blib'), 1, 1, $self->{args}{uninst}||0);
}

sub ACTION_clean {
  my ($self) = @_;
  foreach my $item (keys %{$self->{cleanup}}) {
    $self->delete_filetree($item);
  }
}

sub ACTION_realclean {
  my ($self) = @_;
  $self->depends_on('clean');
  $self->delete_filetree($self->{properties}{config_dir}, $self->{properties}{build_script});
}

sub ACTION_dist {
  my ($self) = @_;
  
  $self->depends_on('distsign') if $self->{properties}{sign};
  $self->depends_on('distdir');
  
  my $dist_dir = $self->dist_dir;
  
  $self->make_tarball($dist_dir);
  $self->delete_filetree($dist_dir);
}

sub ACTION_distcheck {
  my ($self) = @_;
  
  require ExtUtils::Manifest;
  local $^W; # ExtUtils::Manifest is not warnings clean.
  ExtUtils::Manifest::fullcheck();
}

sub ACTION_distsign {
  my ($self) = @_;
  
  unless (eval { require Module::Signature; 1 }) {
    warn "Couldn't load Module::Signature for 'distsign' action:\n $@\n";
    return;
  }
  
  Module::Signature::sign();
}



sub ACTION_skipcheck {
  my ($self) = @_;
  
  require ExtUtils::Manifest;
  local $^W; # ExtUtils::Manifest is not warnings clean.
  ExtUtils::Manifest::skipcheck();
}

sub ACTION_distclean {
  my ($self) = @_;
  
  $self->depends_on('realclean');
  $self->depends_on('distcheck');
}

sub ACTION_distdir {
  my ($self) = @_;

  my $metafile = 'META.yml';
  $self->write_metadata($metafile);

  my $dist_dir = $self->dist_dir;
  
  require ExtUtils::Manifest;  # ExtUtils::Manifest is not warnings clean.
  local ($^W, $ExtUtils::Manifest::Quiet) = (0,1);
  
  my $dist_files = ExtUtils::Manifest::maniread('MANIFEST');
  $self->delete_filetree($dist_dir);
  ExtUtils::Manifest::manicopy($dist_files, $dist_dir, 'best');
  warn "*** Did you forget to add $metafile to the MANIFEST?\n" unless exists $dist_files->{$metafile};
}

sub ACTION_disttest {
  my ($self) = @_;

  $self->depends_on('distdir');

  my $dist_dir = $self->dist_dir;
  chdir $dist_dir or die "Cannot chdir to $dist_dir: $!";
  # XXX could be different names for scripts
  $self->do_system($^X, 'Build.PL') or die "Error executing '$^X Build.PL' in dist directory: $!";
  $self->do_system('./Build') or die "Error executing './Build' in dist directory: $!";
  $self->do_system('./Build', 'test') or die "Error executing './Build test' in dist directory: $!";
  chdir $self->base_dir;
}

sub ACTION_manifest {
  my ($self) = @_;
  
  require ExtUtils::Manifest;  # ExtUtils::Manifest is not warnings clean.
  local ($^W, $ExtUtils::Manifest::Quiet) = (0,1);
  ExtUtils::Manifest::mkmanifest();
}

sub dist_dir {
  my ($self) = @_;
  return "$self->{properties}{dist_name}-$self->{properties}{dist_version}";
}

sub scripts {
  my $self = shift;
  if (@_) {
    $self->{properties}{scripts} = ref($_[0]) ? $_[0] : [@_];
  }
  return $self->{properties}{scripts};
}

sub write_metadata {
  my ($self, $file) = @_;
  my $p = $self->{properties};

  unless ($p->{license}) {
    warn "No license specified, setting license = 'unknown'\n";
    $p->{license} = 'unknown';
  }
  unless (grep {$p->{license} eq $_} qw(perl gpl restrictive artistic unknown)) {
    die "Unknown license type '$p->{license}";
  }

  unless (eval {require YAML; 1}) {
    warn "Couldn't load YAML.pm: $@\n";
    return;
  }

  # We use YAML::Node to get the order nice in the YAML file.
  my $node = YAML::Node->new({});
  
  $node->{name} = $p->{dist_name};
  $node->{version} = $p->{dist_version};
  $node->{license} = $p->{license};
  $node->{distribution_type} = 'module';

  foreach (qw(requires recommends build_requires conflicts dynamic_config)) {
    $node->{$_} = $p->{$_} if exists $p->{$_};
  }
  
  $node->{generated_by} = "Module::Build version " . Module::Build->VERSION;

  return YAML::StoreFile($file, $node ) if $YAML::VERSION le '0.30';
  return YAML::DumpFile( $file, $node );
}

sub make_tarball {
  my ($self, $dir) = @_;
  
  require Archive::Tar;
  my $files = $self->rscan_dir($dir);
  
  print "Creating $dir.tar.gz\n";
  Archive::Tar->create_archive("$dir.tar.gz", 1, @$files);
}

sub install_map {
  my ($self, $blib) = @_;
  my $lib     = File::Spec->catfile($blib,'lib');
  my $arch    = File::Spec->catfile($blib,'arch');
  my $scripts = File::Spec->catfile($blib,'script');
  
  my %map = ($lib  => $self->{config}{sitelib},
	     $arch => $self->{config}{sitearch},
	     read  => '');  # To keep ExtUtils::Install quiet
  
  $map{$scripts} = $self->{config}{installscript};
  
  return \%map;
}

sub depends_on {
  my $self = shift;
  foreach my $action (@_) {
    my $method = "ACTION_$action";
    $self->$method;
  }
}

sub rscan_dir {
  my ($self, $dir, $pattern) = @_;
  my @result;
  my $subr = !$pattern ? sub {push @result, $File::Find::name} :
             !ref($pattern) || (ref $pattern eq 'Regexp') ? sub {push @result, $File::Find::name if /$pattern/} :
	     ref($pattern) eq 'CODE' ? sub {push @result, $File::Find::name if $pattern->()} :
	     die "Unknown pattern type";
  
  File::Find::find({wanted => $subr, no_chdir => 1}, $dir);
  return \@result;
}

sub delete_filetree {
  my $self = shift;
  my $deleted = 0;
  foreach (@_) {
    next unless -e $_;
    print "Deleting $_\n";
    File::Path::rmtree($_, 0, 0);
    die "Couldn't remove '$_': $!\n" if -e $_;
    $deleted++;
  }
  return $deleted;
}

sub lib_to_blib {
  my ($self, $files, $to) = @_;
  
  # Create $to/arch to keep blib.pm happy (what a load of hooie!)
  File::Path::mkpath( File::Spec->catdir($to, 'arch') );

  if ($self->{properties}{autosplit}) {
    $self->autosplit_file($self->{properties}{autosplit}, $to);
  }
  
  foreach my $file (@$files) {
    if ($file =~ /\.p(m|od)$/) {
      # No processing needed
      $self->copy_if_modified($file, $to);

    } elsif ($file =~ /\.xs$/) {
      $self->process_xs($file);

    } else {
      warn "Ignoring file '$file', unknown extension\n";
    }
  }

}

sub autosplit_file {
  my ($self, $file, $to) = @_;
  require AutoSplit;
  my $dir = File::Spec->catdir($to, 'lib', 'auto');
  AutoSplit::autosplit($file, $dir);
}

sub compile_c {
  my ($self, $file) = @_;
  my $cf = $self->{config}; # For convenience

  # File name, minus the suffix
  (my $file_base = $file) =~ s/\.[^.]+$//;
  my $obj_file = "$file_base$cf->{obj_ext}";
  $self->add_to_cleanup($obj_file);
  return $obj_file if $self->up_to_date($file, $obj_file);
  
  my $coredir = File::Spec->catdir($cf->{archlib}, 'CORE');
  my @include_dirs = $self->{include_dirs} ? map {"-I$_"} @{$self->{include_dirs}} : ();
  my @ccflags = $self->split_like_shell($cf->{ccflags});
  my @optimize = $self->split_like_shell($cf->{optimize});
  $self->do_system($cf->{cc}, @include_dirs, '-c', @ccflags, @optimize, "-I$coredir", '-o', $obj_file, $file)
    or die "error building $cf->{dlext} file from '$file'";

  return $obj_file;
}

sub link_c {
  my ($self, $to, $file_base) = @_;
  my $cf = $self->{config}; # For convenience

  my $lib_file = File::Spec->catfile($to, File::Basename::basename("$file_base.$cf->{dlext}"));
  $self->add_to_cleanup($lib_file);
  my $objects = $self->{objects} || [];
  
  unless ($self->up_to_date(["$file_base$cf->{obj_ext}", @$objects], $lib_file)) {
    my @linker_flags = $self->split_like_shell($self->{properties}{extra_linker_flags} || '');
    my @lddlflags = $self->split_like_shell($cf->{lddlflags});
    my @shrp = $self->split_like_shell($cf->{shrpenv});
    $self->do_system(@shrp, $cf->{ld}, @lddlflags, '-o', $lib_file,
		     "$file_base$cf->{obj_ext}", @$objects, @linker_flags)
      or die "error building $file_base$cf->{obj_ext} from '$file_base.$cf->{dlext}'";
  }
}

sub compile_xs {
  my ($self, $file) = @_;
  (my $file_base = $file) =~ s/\.[^.]+$//;

  print "$file -> $file_base.c\n";
  
  if (eval {require ExtUtils::ParseXS; 1}) {
    
    ExtUtils::ParseXS::process_file(
				    filename => $file,
				    prototypes => 0,
				    output => "$file_base.c",
				   );
  } else {
    # Ok, I give up.  Just use backticks.
    
    my $xsubpp  = $self->find_module_by_name('ExtUtils::xsubpp', \@INC)
      or die "Can't find ExtUtils::xsubpp in INC (@INC)";
    
    my $typemap =  $self->find_module_by_name('ExtUtils::typemap', \@INC);
    my $cf = $self->{config};
    
    my $command = (qq{$^X "-I$cf->{archlib}" "-I$cf->{privlib}" "$xsubpp" -noprototypes } .
		   qq{-typemap "$typemap" "$file"});
    
    print $command;
    open my($fh), "> $file_base.c" or die "Couldn't write $file_base.c: $!";
    print $fh `$command`;
    close $fh;
  }
}

sub split_like_shell {
  my $self = shift;
  local $_ = shift;
  return wantarray ? () : '' unless defined() && length();
  
  return split ' ', $_;  # XXX This is naive - needs a fix
}

sub stdout_to_file {
  my ($self, $coderef, $redirect) = @_;
  local *SAVE;
  if ($redirect) {
    open SAVE, ">&STDOUT" or die "Can't save STDOUT handle: $!";
    open STDOUT, "> $redirect" or die "Can't create '$redirect': $!";
  }

  $coderef->();

  if ($redirect) {
    close STDOUT;
    open STDOUT, ">&SAVE" or die "Can't restore STDOUT: $!";
  }
}

sub run_perl_script {
  my ($self, $script, $preargs, $postargs) = @_;
  foreach ($preargs, $postargs) {
    $_ = [ $self->split_like_shell($_) ] unless ref();
  }
  
  return $self->do_system($self->{config}{perlpath}, @$preargs, $script, @$postargs);
}

# A lot of this looks Unixy, but actually it may work fine on Windows.
# I'll see what people tell me about their results.
sub process_xs {
  my ($self, $file) = @_;
  my $cf = $self->{config}; # For convenience

  # File name, minus the suffix
  (my $file_base = $file) =~ s/\.[^.]+$//;

  # .xs -> .c
  unless ($self->up_to_date($file, "$file_base.c")) {
    $self->add_to_cleanup("$file_base.c");
    $self->compile_xs($file);
  }
  
  # .c -> .o
  $self->compile_c("$file_base.c");

  # The .bs and .a files don't go in blib/lib/, they go in blib/arch/auto/.
  # Unfortunately we have to pre-compute the whole path.
  my $archdir;
  {
    my @dirs = File::Spec->splitdir($file_base);
    $archdir = File::Spec->catdir('blib','arch','auto', @dirs[1..$#dirs]);
  }
  
  # .xs -> .bs
  unless ($self->up_to_date($file, "$file_base.bs")) {
    $self->add_to_cleanup("$file_base.bs");
    require ExtUtils::Mkbootstrap;
    print "ExtUtils::Mkbootstrap::Mkbootstrap('$file_base')\n";
    ExtUtils::Mkbootstrap::Mkbootstrap($file_base);  # Original had $BSLOADLIBS - what's that?
    {open my $fh, ">> $file_base.bs"}  # touch
  }
  $self->copy_if_modified("$file_base.bs", $archdir, 1);
  
  # .o -> .(a|bundle)
  $self->link_c($archdir, $file_base);
}

sub do_system {
  my ($self, @cmd) = @_;
  print "@cmd\n";
  return !system(@cmd);
}

sub copy_if_modified {
  my ($self, $file, $to, $flatten) = @_;

  my $to_path;
  if ($flatten) {
    my $basename = File::Basename::basename($file);
    $to_path = File::Spec->catfile($to, $basename);
  } else {
    $to_path = File::Spec->catfile($to, $file);
  }
  return if $self->up_to_date($file, $to_path); # Already fresh
  
  # Create parent directories
  File::Path::mkpath(File::Basename::dirname($to_path), 0, 0777);
  
  print "$file -> $to_path\n";
  File::Copy::copy($file, $to_path) or die "Can't copy('$file', '$to_path'): $!";
  return $to_path;
}

sub up_to_date {
  my ($self, $source, $derived) = @_;
  $source  = [$source]  unless ref $source;
  $derived = [$derived] unless ref $derived;

  return 0 if grep {not -e} @$derived;

  my $most_recent_source = time / (24*60*60);
  foreach my $file (@$source) {
    $most_recent_source = -M $file if -M $file < $most_recent_source;
  }
  
  foreach my $derived (@$derived) {
    return 0 if -M $derived > $most_recent_source;
  }
  return 1;
}

1;
__END__


=head1 NAME

Module::Build::Base - Default methods for Module::Build

=head1 SYNOPSIS

  please see the Module::Build documentation

=head1 DESCRIPTION

The C<Module::Build::Base> module defines the core functionality of
C<Module::Build>.  Its methods may be overridden by any of the
platform-independent modules in the C<Module::Build::Platform::>
namespace, but the intention here is to make this base module as
platform-neutral as possible.  Nicely enough, Perl has several core
tools available in the C<File::> namespace for doing this, so the task
isn't very difficult.

Please see the C<Module::Build> documentation for more details.

=head1 AUTHOR

Ken Williams, ken@forum.swarthmore.edu

=head1 SEE ALSO

perl(1), Module::Build(3)

=cut
