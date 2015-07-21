#!/usr/bin/perl -w

use strict;
use lib 't/lib';
use MBTest;
use CPAN::Meta 2.110420;
use CPAN::Meta::YAML;
use Parse::CPAN::Meta 1.4401;

if (eval { require CPAN::Meta; CPAN::Meta->VERSION(2.142060) }) {
	plan(tests => 4);
	require CPAN::Meta::YAML;
	require Parse::CPAN::Meta;
}
else {
	plan(skip_all => 'No or old CPAN::Meta');
}


blib_load('Module::Build');

my $tmp = MBTest->tmpdir;

use DistGen;
my $dist = DistGen->new( dir => $tmp );
$dist->change_file('Build.PL', <<"---");
use strict;
use Module::Build;

my \$builder = Module::Build->new(
  module_name => '$dist->{name}',
  license => 'perl',
  requires => {
    'File::Spec' => 0,
  },
  test_requires => {
    'Test::More' => 0,
  }
);

\$builder->create_build_script();
---
$dist->regen;
$dist->chdir_in;
$dist->run_build_pl;
my $output = stdout_stderr_of sub { $dist->run_build('distmeta') };

for my $file ( qw/MYMETA META/ ) {
    my $meta = Parse::CPAN::Meta->load_file($file.".json");
    is_deeply($meta->{prereqs}->{runtime},{
        requires => {
            'File::Spec' => '0',
        }
    }, "runtime prereqs in $file");
    is_deeply($meta->{prereqs}->{test},{
        requires => {
            'Test::More' => '0',
        }
    }, "test prereqs in $file");
}

