package Module::Build::Base;

use strict;
BEGIN { require 5.00503 }
use Config;
use File::Copy ();
use File::Find ();
use File::Path ();
use File::Basename ();
use File::Spec ();
use File::Compare ();
use Data::Dumper ();
use IO::File ();

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

  # The following warning could be unnecessary if the user is running
  # an embedded perl, but there aren't too many of those around, and
  # embedded perls aren't usually used to install modules, and the
  # installation process sometimes needs to run external scripts
  # (e.g. to run tests).
  my $perl = $package->find_perl_interpreter
    or warn "Warning: Can't locate your perl binary";

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
				   perl => $perl,
				   install_types => [qw(lib arch script)],
				   include_dirs => [],
				   %input,
				   %$cmd_properties,
				  },
		   }, $package;
  my $p = $self->{properties};

  # Synonyms
  $p->{requires} = delete $p->{prereq} if exists $p->{prereq};
  $p->{script_files} = delete $p->{scripts} if exists $p->{scripts};

  $self->add_to_cleanup( @{delete $p->{add_to_cleanup}} )
    if $p->{add_to_cleanup};
  
  $self->dist_name;
  $self->check_manifest;
  $self->check_prereq;
  $self->dist_version;

  return $self;
}

sub cwd {
  require Cwd;
  return Cwd::cwd();
}

sub find_perl_interpreter {
  my $perl;
  File::Spec->file_name_is_absolute($perl = $^X)
    or -f ($perl = $Config::Config{perlpath})
    or ($perl = $^X);
  return $perl;
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
  
  my $perl = $self->find_perl_interpreter;
  warn(" * WARNING: Configuration was initially created with '$self->{properties}{perl}',\n".
       "   but we are now using '$perl'.\n")
    unless $perl eq $self->{properties}{perl};
  

  ($self->{action}, my $args) = $self->cull_args(@ARGV);
  $self->{action} ||= 'build';
  
  # Extract our 'properties' from $args
  my %p;
  foreach my $key (keys %$args) {
    $p{$key} = delete $args->{$key} if __PACKAGE__->valid_property($key);
  }
  $self->{args} = {%{$self->{args}}, %$args};
  $self->{properties} = {%{$self->{properties}}, %p};

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
       dist_author
       dist_abstract
       requires
       recommends
       pm_files
       xs_files
       pod_files
       PL_files
       scripts
       script_files
       perl
       config_dir
       build_script
       install_types
       destdir
       debugger
       verbose
       c_source
       autosplit
       create_makefile_pl
       pollute
       include_dirs
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
  
  my $fh = IO::File->new("> $filename") or die "Can't create $filename: $!";
  print $fh <<EOF;
package $opts{class};
use Module::Build;
\@ISA = qw(Module::Build);
$opts{code}
1;
EOF
  close $fh;
  
  push @INC, File::Spec->catdir(File::Spec->rel2abs($build_dir), 'lib');
  eval "use $opts{class}";
  die $@ if $@;

  return $opts{class};
}

sub dist_name {
  my $self = shift;
  my $p = $self->{properties};
  return $p->{dist_name} if exists $p->{dist_name};
  
  die "Can't determine distribution name, must supply either 'dist_name' or 'module_name' parameter"
    unless $p->{module_name};
  
  ($p->{dist_name} = $p->{module_name}) =~ s/::/-/g;
  
  return $p->{dist_name};
}

sub dist_version {
  my ($self) = @_;
  my $p = $self->{properties};
  
  return $p->{dist_version} if exists $p->{dist_version};
  
  if (exists $p->{module_name}) {
    $p->{dist_version_from} ||= join( '/', 'lib', split '::', $p->{module_name} ) . '.pm';
  }
  
  die ("Can't determine distribution version, must supply either 'dist_version',\n".
       "'dist_version_from', or 'module_name' parameter")
    unless $p->{dist_version_from};
  
  my $version_from = File::Spec->catfile( split '/', $p->{dist_version_from} );
  
  return $p->{dist_version} = $self->version_from_file($version_from);
}

sub dist_author {
  my $self = shift;
  my $p = $self->{properties};
  return $p->{dist_author} if exists $p->{dist_author};
  
  # Figure it out from 'dist_version_from'
  return unless $p->{dist_version_from};
  my $fh = IO::File->new($p->{dist_version_from}) or return;
  
  my @author;
  local $_;
  while (<$fh>) {
    next unless /^=head1\s+AUTHOR/ ... /^=/;
    next if /^=/;
    push @author, $_;
  }
  return unless @author;
  
  my $author = join '', @author;
  $author =~ s/^\s+|\s+$//g;
  return $p->{dist_author} = $author;
}

sub dist_abstract {
  my $self = shift;
  my $p = $self->{properties};
  return $p->{dist_abstract} if exists $p->{dist_abstract};
  
  # Figure it out from 'dist_version_from'
  return unless $p->{dist_version_from};
  my $fh = IO::File->new($p->{dist_version_from}) or return;
  
  (my $package = $self->dist_name) =~ s/-/::/g;
  
  my $result;
  local $_;
  while (<$fh>) {
    next unless /^=(?!cut)/ .. /^cut/;  # in POD
    last if ($result) = /^(?:$package\s-\s)(.*)/;
  }
  
  return $p->{dist_abstract} = $result;
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
  my $fh = IO::File->new($file) or die "Can't open '$file' for version: $!";
  local $_;
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

sub _write_cleanup {
  my $self = shift;
  my @to_write = keys %{ $self->{add_to_cleanup} }
    or return;
  
  my $file = $self->config_file('cleanup');
  my $fh = IO::File->new(">> $file") or die "Can't write to $file: $!";
  print $fh "$_\n" foreach @to_write;
  close $fh;
  
  @{ $self->{cleanup} }{ @to_write } = ();
  $self->{add_to_cleanup} = {};
}

sub cleanup_is_flushed {
  my $self = shift;
  return ! keys %{ $self->{add_to_cleanup} };
}

sub add_to_cleanup {
  my $self = shift;

  # $self->{cleanup} contains files that are already written in the
  # 'cleanup' file.  $self->{add_to_cleanup} is a buffer that we
  # haven't written yet (and may never write if we don't ever create
  # the cleanup file).
  
  my @new_files = grep {!exists $self->{cleanup}{$_}} @_
    or return;
  
  @{$self->{add_to_cleanup}}{ @new_files } = ();
  
  $self->_write_cleanup if $self->config_file('cleanup');
}

sub cleanup {
  my $self = shift;
  return (keys %{$self->{cleanup}}, keys %{$self->{add_to_cleanup}});
}

sub config_file {
  my $self = shift;
  return unless -d $self->{properties}{config_dir};
  return File::Spec->catfile($self->{properties}{config_dir}, @_);
}

sub read_config {
  my ($self) = @_;
  
  my $file = $self->config_file('build_params');
  my $fh = IO::File->new($file) or die "Can't read '$file': $!";
  my $ref = eval do {local $/; <$fh>};
  die if $@;
  ($self->{args}, $self->{config}, $self->{properties}) = @$ref;
  close $fh;
  
  my $cleanup_file = $self->config_file('cleanup');
  $self->{cleanup} = {};
  if (-e $cleanup_file) {
    my $fh = IO::File->new($cleanup_file) or die "Can't read '$file': $!";
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
  my $fh = IO::File->new("> $file") or die "Can't create '$file': $!";
  print $fh Data::Dumper::Dumper([$self->{args}, $self->{config}, $self->{properties}]);
  close $fh;

  $file = $self->config_file('prereqs');
  open $fh, "> $file" or die "Can't create '$file': $!";
  my @items = qw(requires build_requires conflicts recommends);
  print $fh Data::Dumper::Dumper( { map { $_, $self->$_() } @items } );
  close $fh;
  
  $self->_write_cleanup;
}

sub requires       { shift()->{properties}{requires} }
sub recommends     { shift()->{properties}{recommends} }
sub build_requires { shift()->{properties}{build_requires} }
sub conflicts      { shift()->{properties}{conflicts} }

sub prereq_failures {
  my $self = shift;

  my @types = qw(requires recommends build_requires conflicts);
  my $out;

  foreach my $type (@types) {
    while ( my ($modname, $spec) = each %{$self->$type()} ) {
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

sub perl_version {
  my ($self) = @_;
  # Check the current perl interpreter
  # It's much more convenient to use $] here than $^V, but 'man
  # perlvar' says I'm not supposed to.  Bloody tyrant.
  return $^V ? $self->perl_version_to_float(sprintf "%vd", $^V) : $];
}

sub perl_version_to_float {
  my ($self, $version) = @_;
  $version =~ s/\./../;
  $version =~ s/\.(\d+)/sprintf '%03d', $1/eg;
  return $version;
}

sub _parse_conditions {
  my ($self, $spec) = @_;

  if ($spec =~ /^\s*([\w.]+)\s*$/) { # A plain number, maybe with dots, letters, and underscores
    return (">= $spec");
  } else {
    return split /\s*,\s*/, $spec;
  }
}

sub check_installed_status {
  my ($self, $modname, $spec) = @_;
  my %status = (need => $spec);
  
  if ($modname eq 'perl') {
    # Check the current perl interpreter
    # It's much more convenient to use $] here than $^V, but 'man
    # perlvar' says I'm not supposed to.  Bloody tyrant.
    $status{have} = $self->perl_version;
  
  } elsif (eval { $status{have} = $modname->VERSION }) {
    # Don't try to load if it's already loaded
    
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
  
  my @conditions = $self->_parse_conditions($spec);
  
  foreach (@conditions) {
    my ($op, $version) = /^\s*  (<=?|>=?|==|!=)  \s*  ([\w.]+)  \s*$/x
      or die "Invalid prerequisite condition '$_' for $modname";
    
    $version = $self->perl_version_to_float($version)
      if $modname eq 'perl';
    
    next if $op eq '>=' and !$version;  # Module doesn't have to actually define a $VERSION
    
    unless (eval "\$status{have} $op \$version") {
      warn $@ if $@;
      $status{message} = "Version $status{have} is installed, but we need version $op $version";
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
    $_ = File::Spec->rel2abs($_);
    s/([\\\'])/\\$1/g;
  }

  my $quoted_INC = join ",\n", map "     '$_'", @myINC;

  print $fh <<EOF;
$self->{config}{startperl}

BEGIN {
  \$^W = 1;  # Use warnings
  my \$start_dir = '$base_dir';
  chdir(\$start_dir) or die "Cannot chdir to \$start_dir: \$!";
  \@INC = 
    (
$quoted_INC
    );
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
  my $fh = IO::File->new(">$p->{build_script}") or die "Can't create '$p->{build_script}': $!";
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

  if (@_) {
    (local $self->{action}, my %p) = @_;
    my $args = $p{args} ? delete($p{args}) : {};
    
    local $self->{args} = {%{$self->{args}}, %$args};
    local $self->{properties} = {%{$self->{properties}}, %p};
    return $self->_call_action($self->{action});
  }

  die "No build action specified" unless $self->{action};
  $self->_call_action($self->{action});
}

sub _call_action {
  my ($self, $action) = @_;
  my $method = "ACTION_$self->{action}";
  die "No action '$self->{action}' defined" unless $self->can($method);
  return $self->$method();
}

sub cull_args {
  my $self = shift;
  my ($action, %args);
  foreach (@_) {
    if ( /^(\w+)=(.*)/ ) {
      if ( exists $args{$1} ) {
        $args{$1} = [ $args{$1} ] unless ref $args{$1};
        push @{$args{$1}}, $2;
      } else {
        $args{$1} = $2;
      }
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
  $class ||= ref($self) || $self;
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
  my $p = $self->{properties};
  require Test::Harness;
  
  $self->depends_on('build');
  
  # Do everything in our power to work with all versions of Test::Harness
  local ($Test::Harness::switches,
	 $Test::Harness::Switches,
         $ENV{HARNESS_PERL_SWITCHES}) = ($p->{debugger} ? '-w -d' : '') x 3;

  local ($Test::Harness::verbose,
	 $Test::Harness::Verbose,
	 $ENV{TEST_VERBOSE},
         $ENV{HARNESS_VERBOSE}) = ($p->{verbose} || 0) x 4;

  # Make sure we test the module in blib/
  local @INC = (File::Spec->catdir($p->{base_dir}, 'blib', 'lib'),
		File::Spec->catdir($p->{base_dir}, 'blib', 'arch'),
		@INC);
  
  my $tests = $self->test_files;

  if (@$tests) {
    # Work around a Test::Harness bug that loses the particular perl we're running under
    local $^X = $self->{config}{perlpath} unless $Test::Harness::VERSION gt '2.01';
    Test::Harness::runtests(@$tests);
  } else {
    print("No tests defined.\n");
  }

  # This will get run and the user will see the output.  It doesn't
  # emit Test::Harness-style output.
  if (-e 'visual.pl') {
    $self->run_perl_script('visual.pl', '-Mblib');
  }
}

sub test_files {
  my $self = shift;
  
  my @tests;
  if ($self->{args}{test_files}) {
    @tests = $self->split_like_shell($self->{args}{test_files});
  } else {
    # Find all possible tests in t/ or test.pl
    push @tests, 'test.pl'                          if -e 'test.pl';
    push @tests, @{$self->rscan_dir('t', qr{\.t$})} if -e 't' and -d _;
  }
  return [sort @tests];
}

sub ACTION_testdb {
  my ($self) = @_;
  local $self->{properties}{debugger} = 1;
  $self->depends_on('test');
}

sub ACTION_build {
  my ($self) = @_;
  
  # All installable stuff gets created in blib/ .
  # Create blib/arch to keep blib.pm happy
  my $blib = 'blib';
  $self->add_to_cleanup($blib);
  File::Path::mkpath( File::Spec->catdir($blib, 'arch') );
  
  if ($self->{properties}{autosplit}) {
    $self->autosplit_file($self->{properties}{autosplit}, $blib);
  }
  
  $self->process_PL_files;
  
  $self->compile_support_files;
  
  $self->process_pm_files;
  $self->process_xs_files;
  $self->process_pod_files;
  $self->process_script_files;
}

sub compile_support_files {
  my $self = shift;
  my $p = $self->{properties};
  return unless $p->{c_source};
  
  push @{$p->{include_dirs}}, $p->{c_source};
  
  my $files = $self->rscan_dir($p->{c_source}, qr{\.c(pp)?$});
  foreach my $file (@$files) {
    push @{$p->{objects}}, $self->compile_c($file);
  }
}

sub process_PL_files {
  my ($self) = @_;
  my $files = $self->find_PL_files;
  
  while (my ($file, $to) = each %$files) {
    unless ($self->up_to_date( $file, $to )) {
      $self->run_perl_script($file);
      $self->add_to_cleanup(@$to);
    }
  }
}

sub process_xs_files {
  my $self = shift;
  my $files = $self->find_xs_files;
  while (my ($from, $to) = each %$files) {
    $self->copy_if_modified( from => $from, to => $to ) unless $from eq $to;
    $self->process_xs($to);
  }
}

sub process_pod_files {
  my $self = shift;
  my $files = $self->find_pod_files;
  while (my ($file, $dest) = each %$files) {
    $self->copy_if_modified(from => $file, to => File::Spec->catfile('blib', $dest) );
  }
}

sub process_pm_files {
  my $self = shift;
  my $files = $self->find_pm_files;
  while (my ($file, $dest) = each %$files) {
    $self->copy_if_modified(from => $file, to => File::Spec->catfile('blib', $dest) );
  }
}

sub process_script_files {
  my $self = shift;
  my $files = $self->find_script_files;
  return unless keys %$files;

  my $script_dir = File::Spec->catdir('blib', 'script');
  File::Path::mkpath( $script_dir );
  
  foreach my $file (keys %$files) {
    my $result = $self->copy_if_modified($file, $script_dir, 'flatten') or next;
    $self->fix_shebang_line($result);
    $self->make_executable($result);
  }
}

sub find_PL_files {
  my $self = shift;
  if (my $files = $self->{properties}{PL_files}) {
    # 'PL_files' is given as a Unix file spec, so we localize_file_path().
    
    if (UNIVERSAL::isa($files, 'ARRAY')) {
      return { map {$_, /^(.*)\.PL$/}
	       map $self->localize_file_path($_),
	       @$files };

    } elsif (UNIVERSAL::isa($files, 'HASH')) {
      my %out;
      while (my ($file, $to) = each %$files) {
	$out{ $self->localize_file_path($file) } = [ map $self->localize_file_path($_),
						     ref $to ? @$to : ($to) ];
      }
      return \%out;

    } else {
      die "'PL_files' must be a hash reference or array reference";
    }
  }
  
  return unless -d 'lib';
  return { map {$_, /^(.*)\.PL$/} @{ $self->rscan_dir('lib', qr{\.PL$}) } };
}

sub find_pm_files { shift->_find_file_by_type('pm') }
sub find_pod_files { shift->_find_file_by_type('pod') }
sub find_xs_files { shift->_find_file_by_type('xs') }

sub find_script_files {
  my $self = shift;
  if (my $files = $self->{properties}{"script_files"}) {
    $files = { map {$_, undef} @$files } if UNIVERSAL::isa($files, 'ARRAY');
    
    # Always given as a Unix file spec.  Values in the hash are
    # meaningless, but we preserve if present.
    return { map {$self->localize_file_path($_), $files->{$_}} keys %$files };
  }
  
  # No default location for script files
  return {};
}

sub _find_file_by_type {
  my ($self, $type) = @_;
  if (my $files = $self->{properties}{"${type}_files"}) {
    # Always given as a Unix file spec
    return { map $self->localize_file_path($_), %$files };
  }
  
  return unless -d 'lib';
  return { map {$_, $_} @{ $self->rscan_dir('lib', qr{\.$type$}) } };
}

sub localize_file_path {
  my ($self, $path) = @_;
  return File::Spec->catfile( split qr{/}, $path );
}

sub fix_shebang_line { # Adapted from fixin() in ExtUtils::MM_Unix 1.35
  my ($self, @files) = @_;
  my $c = $self->{config};
  
  my ($does_shbang) = $c->{sharpbang} =~ /^\s*\#\!/;
  for my $file (@files) {
    my $FIXIN = IO::File->new($file) or die "Can't process '$file': $!";
    local $/ = "\n";
    chomp(my $line = <$FIXIN>);
    next unless $line =~ s/^\s*\#!\s*//;     # Not a shbang file.
    
    my ($cmd, $arg) = (split(' ', $line, 2), '');
    my $interpreter = $self->{properties}{perl};
    
    print STDOUT "Changing sharpbang in $file to $interpreter" if $self->{verbose};
    my $shb = '';
    $shb .= "$c->{sharpbang}$interpreter $arg\n" if $does_shbang;
    
    # I'm not smart enough to know the ramifications of changing the
    # embedded newlines here to \n, so I leave 'em in.
    $shb .= qq{
eval 'exec $interpreter $arg -S \$0 \${1+"\$\@"}'
    if 0; # not running under some shell
} unless $self->os_type eq 'Windows'; # this won't work on win32, so don't
    
    my $FIXOUT = IO::File->new(">$file.new")
      or die "Can't create new $file: $!\n";
    
    # Print out the new #! line (or equivalent).
    local $\;
    undef $/; # Was localized above
    print $FIXOUT $shb, <$FIXIN>;
    close $FIXIN;
    close $FIXOUT;
    
    rename($file, "$file.bak")
      or die "Can't rename $file to $file.bak: $!";
    
    rename("$file.new", $file)
      or die "Can't rename $file.new to $file: $!";
    
    unlink "$file.bak"
      or warn "Couldn't clean up $file.bak, leaving it there";
    
    $self->do_system($c->{eunicefix}, $file) if $c->{eunicefix} ne ':';
  }
}


sub ACTION_manifypods {
  my $self = shift;
  warn "Sorry, the 'manifypods' action is not yet implemented.\n"; return;
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

sub ACTION_versioninstall {
  my ($self) = @_;
  
  die "You must have only.pm 0.25 or greater installed for this operation: $@\n"
    unless eval { require only; 'only'->VERSION(0.25); 1 };
  
  $self->depends_on('build');
  
  my %onlyargs = map {exists($self->{args}{$_}) ? ($_ => $self->{args}{$_}) : ()}
    qw(version versionlib);
  only::install::install(%onlyargs);
}

sub ACTION_clean {
  my ($self) = @_;
  foreach my $item ($self->cleanup) {
    $self->delete_filetree($item);
  }
}

sub ACTION_realclean {
  my ($self) = @_;
  $self->depends_on('clean');
  $self->delete_filetree($self->{properties}{config_dir}, $self->{properties}{build_script});
}

sub ACTION_ppd {
  my ($self) = @_;
  require Module::Build::PPMMaker;
  my $ppd = Module::Build::PPMMaker->new(archname => $self->{config}{archname});
  my $file = $ppd->make_ppd(%{$self->{args}}, build => $self);
  $self->add_to_cleanup($file);
}

sub ACTION_dist {
  my ($self) = @_;
  
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

  # We protect the signing with an eval{} to make sure we get back to
  # the right directory after a signature failure.
  
  chdir $self->dist_dir or die "Can't chdir() to " . $self->dist_dir . ": $!";
  eval {Module::Signature::sign()};
  my @err = $@ ? ($@) : ();
  chdir $self->base_dir or push @err, "Can't chdir() back to " . $self->base_dir . ": $!";
  die join "\n", @err if @err;
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

  $self->depends_on('distmeta');

  my $dist_dir = $self->dist_dir;

  if ($self->{properties}{create_makefile_pl}) {
    require Module::Build::Compat;
    Module::Build::Compat->create_makefile_pl($self->{properties}{create_makefile_pl}, $self);
  }
  
  require ExtUtils::Manifest;  # ExtUtils::Manifest is not warnings clean.
  local ($^W, $ExtUtils::Manifest::Quiet) = (0,1);
  
  my $dist_files = ExtUtils::Manifest::maniread('MANIFEST');
  $self->delete_filetree($dist_dir);
  $self->add_to_cleanup($dist_dir);
  ExtUtils::Manifest::manicopy($dist_files, $dist_dir, 'best');
  warn "*** Did you forget to add $self->{metafile} to the MANIFEST?\n" unless exists $dist_files->{$self->{metafile}};
  
  $self->depends_on('distsign') if $self->{properties}{sign};
}

sub ACTION_disttest {
  my ($self) = @_;

  $self->depends_on('distdir');

  my $dist_dir = $self->dist_dir;
  chdir $dist_dir or die "Cannot chdir to $dist_dir: $!";
  # XXX could be different names for scripts
  # XXX doesn't propagate @INC
  $self->run_perl_script('Build.PL') or die "Error executing 'Build.PL' in dist directory: $!";
  $self->run_perl_script('Build') or die "Error executing 'Build' in dist directory: $!";
  $self->run_perl_script('Build', [], ['test']) or die "Error executing 'Build test' in dist directory";
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

sub script_files {
  my $self = shift;
  if (@_) {
    $self->{properties}{script_files} = ref($_[0]) ? $_[0] : [@_];
  }
  return $self->{properties}{script_files};
}
*scripts = \&script_files;

sub valid_licenses {
  return { map {$_, 1} qw(perl gpl artistic lgpl bsd open_source unrestricted restrictive unknown) };
}

sub ACTION_distmeta {
  my ($self) = @_;
  return if $self->{wrote_metadata};
  
  my $p = $self->{properties};
  $self->{metafile} = 'META.yml';
  
  unless ($p->{license}) {
    warn "No license specified, setting license = 'unknown'\n";
    $p->{license} = 'unknown';
  }
  unless ($self->valid_licenses->{ $p->{license} }) {
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
  
  $node->{provides} = $self->find_dist_packages
    or do {
      warn "Module::Info was not available, no 'provides' will be created in $self->{metafile}";
      delete $node->{provides};
    };

  $node->{generated_by} = "Module::Build version " . Module::Build->VERSION;

  # YAML API changed after version 0.30
  my $yaml_sub = $YAML::VERSION le '0.30' ? \&YAML::StoreFile : \&YAML::DumpFile;
  return $self->{wrote_metadata} = $yaml_sub->($self->{metafile}, $node );
}

sub find_dist_packages {
  my $self = shift;
  
  # Only packages in .pm files are candidates for inclusion here.
  my @pm_files = keys %{ $self->find_pm_files };
  
  my %out;
  foreach my $file (@pm_files) {
    next if $file =~ m{^t/};  # Skip things in t/
    
    return unless eval {require Module::Info; Module::Info->VERSION(0.19); 1};
    
    my $localfile = File::Spec->catfile( split m{/}, $file );
    my $version = $self->version_from_file( $localfile );

    print "Scanning $localfile for packages\n";
    my $module = Module::Info->new_from_file( $localfile );

    foreach my $package ($module->packages_inside) {
      $out{$package} = {
			file => $file,
			version => $version,
		       };
    }
  }
  return \%out;
}

sub make_tarball {
  my ($self, $dir) = @_;
  
  require Archive::Tar;
  my $files = $self->rscan_dir($dir);
  
  print "Creating $dir.tar.gz\n";
  Archive::Tar->create_archive("$dir.tar.gz", 1, @$files);
}

sub install_destination {
  my ($self, $type) = @_;
  my $c = $self->{config};

  my %map = ( core => {
		       arch   => $c->{installarchlib},
		       lib    => $c->{installprivlib},
		       bin    => $c->{installbin},
		       script => $c->{installscript},
		       man1   => $c->{installman1dir},
		       man3   => $c->{installman3dir},
		      },
	      site => {
		       arch   => $c->{installsitearch},
		       lib    => $c->{installsitelib},
		       bin    => $c->{installsitebin},
		       script => $c->{installsitescript} || $c->{installsitebin},
		       man1   => $c->{installsiteman1dir},
		       man3   => $c->{installsiteman3dir},
		      },
	    vendor => {
		       arch   => $c->{installvendorarch},
		       lib    => $c->{installvendorlib},
		       bin    => $c->{installvendorbin},
		       script => $c->{installvendorscript} || $c->{installvendorbin},
		       man1   => $c->{installvendorman1dir},
		       man3   => $c->{installvendorman3dir},
		      },
	    );
  
  my $installdirs = $self->{properties}{installdirs} || 'site';
  return $map{$installdirs}{$type};
}

sub install_types {
  my $self = shift;
  return @{ $self->{properties}{install_types} }
}

sub install_map {
  my ($self, $blib) = @_;

  my %map;
  foreach my $type ($self->install_types) {
    my $localdir = File::Spec->catdir( $blib, $type );
    next unless -e $localdir;
    
    $map{$localdir} = $self->install_destination($type)
      or die "Can't figure out where to install things of type '$type'";
  }

  if (length(my $destdir = $self->{properties}{destdir} || '')) {
    foreach (keys %map) {
      # Need to remove volume from $map{$_} using splitpath, or else
      # we'll create something crazy like C:\Foo\Bar\E:\Baz\Quux
      my ($volume, $path) = File::Spec->splitpath( $map{$_}, 1 );
      $map{$_} = File::Spec->catdir($destdir, $path);
    }
  }
  
  $map{read} = '';  # To keep ExtUtils::Install quiet
  
  return \%map;
}

sub depends_on {
  my $self = shift;
  foreach my $action (@_) {
    $self->dispatch($action);
  }
}

sub rscan_dir {
  my ($self, $dir, $pattern) = @_;
  my @result;
  local $_; # find() can overwrite $_, so protect ourselves
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

sub autosplit_file {
  my ($self, $file, $to) = @_;
  require AutoSplit;
  my $dir = File::Spec->catdir($to, 'lib', 'auto');
  AutoSplit::autosplit($file, $dir);
}

sub compile_c {
  my ($self, $file) = @_;
  my ($cf, $p) = ($self->{config}, $self->{properties}); # For convenience
  
  # File name, minus the suffix
  (my $file_base = $file) =~ s/\.[^.]+$//;
  my $obj_file = "$file_base$cf->{obj_ext}";
  $self->add_to_cleanup($obj_file);
  return $obj_file if $self->up_to_date($file, $obj_file);
  
  my @include_dirs = map {"-I$_"} (@{$p->{include_dirs}},
				   File::Spec->catdir($cf->{installarchlib}, 'CORE'));
  
  my @extra_compiler_flags = $self->split_like_shell($p->{extra_compiler_flags});
  my @ccflags = $self->split_like_shell($cf->{ccflags});
  my @optimize = $self->split_like_shell($cf->{optimize});
  my @cc = $self->split_like_shell($cf->{cc});
  
  $self->do_system(@cc, @include_dirs, @extra_compiler_flags, '-c', @ccflags, @optimize, '-o', $obj_file, $file)
    or die "error building $cf->{dlext} file from '$file'";

  return $obj_file;
}

sub link_c {
  my ($self, $to, $file_base) = @_;
  my ($cf, $p) = ($self->{config}, $self->{properties}); # For convenience

  my $lib_file = File::Spec->catfile($to, File::Basename::basename("$file_base.$cf->{dlext}"));
  $self->add_to_cleanup($lib_file);
  my $objects = $p->{objects} || [];
  
  unless ($self->up_to_date(["$file_base$cf->{obj_ext}", @$objects], $lib_file)) {
    my @linker_flags = $self->split_like_shell($p->{extra_linker_flags});
    my @lddlflags = $self->split_like_shell($cf->{lddlflags});
    my @shrp = $self->split_like_shell($cf->{shrpenv});
    my @ld = $self->split_like_shell($cf->{ld});
    $self->do_system(@shrp, @ld, @lddlflags, '-o', $lib_file,
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
    
    my $command = (qq{$^X "-I$cf->{installarchlib}" "-I$cf->{installprivlib}" "$xsubpp" -noprototypes } .
		   qq{-typemap "$typemap" "$file"});
    
    print $command;
    my $fh = IO::File->new("> $file_base.c") or die "Couldn't write $file_base.c: $!";
    print $fh `$command`;
    close $fh;
  }
}

sub split_like_shell {
  my ($self, $string) = @_;
  
  return () unless defined($string) && length($string);
  return @$string if UNIVERSAL::isa($string, 'ARRAY');
  
  return $self->shell_split($string);
}

sub shell_split {
  return split ' ', $_[1];  # XXX This is naive - needs a fix
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
  
  return $self->do_system($self->{properties}{perl}, @$preargs, $script, @$postargs);
}

# A lot of this looks Unixy, but actually it may work fine on Windows.
# I'll see what people tell me about their results.
sub process_xs {
  my ($self, $file) = @_;
  my $cf = $self->{config}; # For convenience

  # File name, minus the suffix
  (my $file_base = $file) =~ s/\.[^.]+$//;

  # .xs -> .c
  $self->add_to_cleanup("$file_base.c");
  unless ($self->up_to_date($file, "$file_base.c")) {
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
  $self->add_to_cleanup("$file_base.bs");
  unless ($self->up_to_date($file, "$file_base.bs")) {
    require ExtUtils::Mkbootstrap;
    print "ExtUtils::Mkbootstrap::Mkbootstrap('$file_base')\n";
    ExtUtils::Mkbootstrap::Mkbootstrap($file_base);  # Original had $BSLOADLIBS - what's that?
    {my $fh = IO::File->new(">> $file_base.bs")}  # touch
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
  my $self = shift;
  my %args = @_ > 3 ? @_ : ( from => shift, to_dir => shift, flatten => shift );
  
  my $file = $args{from};
  my $to_path = $args{to} || File::Spec->catfile( $args{to_dir}, $args{flatten}
						  ? File::Basename::basename($file)
						  : $file );
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
    unless (-e $file) {
      warn "Can't find source file $file for up-to-date check";
      next;
    }
    $most_recent_source = -M _ if -M _ < $most_recent_source;
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
