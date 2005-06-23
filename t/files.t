
use strict;

use Test::More tests => 6;

use File::Spec;
use IO::File;

use Module::Build;
ok(1);


my $m = Module::Build->current;
my @files;

{
  # Make sure copy_if_modified() can handle spaces in filenames
  
  my @tmp;
  foreach (1..2) {
    my $tmp = File::Spec->catdir('t', "tmp$_");
    $m->add_to_cleanup($tmp);
    push @files, $tmp;
    unless (-d $tmp) {
      mkdir($tmp, 0777) or die "Can't create $tmp: $!";
    }
    ok -d $tmp;
    $tmp[$_] = $tmp;
  }
  
  my $filename = 'file with spaces.txt';
  
  my $file = File::Spec->catfile($tmp[1], $filename);
  my $fh = IO::File->new($file, '>') or die "Can't create $file: $!";
  print $fh "Foo\n";
  $fh->close;
  ok -e $file;
  
  
  my $file2 = $m->copy_if_modified(from => $file, to_dir => $tmp[2]);
  ok $file2;
  ok -e $file2;
}

$m->delete_filetree(@files);
