#!/usr/bin/perl

use warnings;
use strict;

# Copyright (C) 2007, Eric L. Wilhelm
# License: perl

=head1 NAME

update_versionpm - fetch version.pm from CPAN and update our code

=head1 Synopsis

=over

=item 1. Fetch vpp.pm.

=item 2. fixup Module::Build::Version

Includes the '$VERSION=...' bit and the embedded vpp.pm code.

=item 3. Set the new recommended version in Build.PL

=back

=head1 Assumptions

=over

=item 1. You have svn/svk/whatever -- no backups of files.

=item 2. The change has not already happened.

=item 3. Your CPAN.pm is configured correctly and you have wget.

=back

You can bypass #3 by fetching vpp.pm yourself and giving it as an
argument to this script:

  update_versionpm.pl vpp.pm

=cut

my $vpp = shift(@ARGV);

unless($vpp) {
  eval {
    require CPAN; $CPAN::Config = $CPAN::Config;
    require File::Temp;
    require File::Basename;
    require Archive::Tar;
    require Cwd;
  };
  if($@) {
    die "missing some tools:\n  $@",
    "\n\nfetch vpp.pm manually and give it as the argument";
  }

  my $tmpdir =
    File::Temp::tempdir('version-' . 'X'x8, TMPDIR => 1, CLEANUP => 1);
  my $retdir = Cwd::getcwd();

  chdir($tmpdir) or die "cannot chdir '$tmpdir' $!";

  my $get = do {
    my $obj = CPAN::Shell->expand('Module', 'version');
    $CPAN::Config->{urllist}[0] .
      '/authors/id/' . $obj->cpan_file;
  };
  system('wget', $get) and die "cannot fetch $get";
  my $got = File::Basename::basename($get);
  my @files = Archive::Tar->new($got, 1)->extract;
  ($vpp) = grep(/vpp\.pm$/, map({$_->full_path} @files));
  $vpp or die "found no vpp in @files";
  chdir($retdir) or die "cannot chdir '$retdir' $!";
  $vpp = "$tmpdir/$vpp";
  warn "fetched $vpp\n";
}

my $v_version;
my $v_content = '';
{ # read vpp.pm and grab the version number too
  open(my $vfh, '<', $vpp) or die "cannot open $vpp -- $!";
  while(my $line = <$vfh>) {
    if($line =~ m/^\$VERSION = (\d\.\d+);/) {
      defined($v_version) and die "defined version twice?";
      $v_version = $1;
    }
    $v_content .= $line;
  }
}

my $mbv_file  = 'lib/Module/Build/Version.pm';
my $repl_flag = qr/^# replace everything from here to the end/;

my @mbv_content = sub { # read and fix the mbv content
  my @mbv;
  my $set_v;
  open(my $fh, '<', $mbv_file) or die "cannot read $mbv_file $!";
  while(my $line = <$fh>) {

    if($line =~ m/$repl_flag/) {
      return(@mbv, $line, $v_content);
    }

    unless($set_v) {
      if($line =~ s/^(\$VERSION = )(\d\.\d+);/$1$v_version;/) {
        my $old_version = $2;
        unless(($old_version > 0) and ($old_version < $v_version)) {
          die "error in version update ($old_version => $v_version)";
        }
        $set_v = 1;
      }
    }
    push(@mbv, $line);
  }
  # if we hit the end of the file, we missed the flag
  die "could not find $repl_flag in $mbv_file";
}->();

# and update
{
  open(my $outfh, '>', $mbv_file) or die "cannot write '$mbv_file' $!";
  print $outfh @mbv_content;
}

# then fix the Build.PL recommends
my @build = do {
  open(my $fh, '<', 'Build.PL') or die "cannot read Build.PL $!";
  my @ans;
  my $set_v;
  while(my $line = <$fh>) {
    if($line =~ s/('version'\s*=>\s*)(\d\.\d+)/$1$v_version/) {
      # TODO check old_version?
      $set_v and die "already set version recommends once!";
      $set_v = 1;
    }
    push(@ans, $line);
  }
  @ans;
};
{
  open(my $outfh, '>', 'Build.PL') or die "cannot write 'Build.PL' $!";
  print $outfh @build;
}

warn "ok\n";

# vim:ts=2:sw=2:et:sta
