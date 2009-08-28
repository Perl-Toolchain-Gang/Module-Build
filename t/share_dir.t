#!/usr/bin/perl -w

use strict;
use lib $ENV{PERL_CORE} ? '../lib/Module/Build/t/lib' : 't/lib';
use MBTest; 
use File::Spec::Functions qw/catdir catfile/;

#--------------------------------------------------------------------------#
# Begin testing
#--------------------------------------------------------------------------#

plan tests => 12;

require_ok('Module::Build');
ensure_blib('Module::Build');

#--------------------------------------------------------------------------#
# Create test distribution
#--------------------------------------------------------------------------#

my $tmp = MBTest->tmpdir;

use DistGen;
my $dist = DistGen->new( dir => $tmp );

$dist->regen;
END{ $dist->remove }

$dist->chdir_in;

#--------------------------------------------------------------------------#
# Test setting 'share_dir'
#--------------------------------------------------------------------------#

my $mb = $dist->new_from_context;

# Test without a 'share' dir
ok( $mb, "Created Module::Build object" );
is( $mb->share_dir, undef,
  "default share undef if no 'share' dir exists"
);

# Add 'share' dir and an 'other' dir and content
$dist->add_file('share/foo.txt',<< '---');
This is foo.txt
---
$dist->add_file('other/bar.txt',<< '---');
This is bar.txt
---
$dist->regen;
ok( -e catfile(qw/share foo.txt/), "Created 'share' directory" );

# Check default when share_dir is not given
$mb = $dist->new_from_context;
is_deeply( $mb->share_dir, { dist => [ 'share' ] },
  "Default share_dir set as dist-type share"
);

# share_dir set to scalar
$dist->change_build_pl(
  {
    module_name         => $dist->name,
    license             => 'perl',
    share_dir           => 'share',
  }
);
$dist->regen;
$mb = $dist->new_from_context;
is_deeply( $mb->share_dir, { dist => [ 'share' ] },
  "Scalar share_dir set as dist-type share"
);

# share_dir set to arrayref
$dist->change_build_pl(
  {
    module_name         => $dist->name,
    license             => 'perl',
    share_dir           => [ 'share' ],
  }
);
$dist->regen;
$mb = $dist->new_from_context;
is_deeply( $mb->share_dir, { dist => [ 'share' ] },
  "Arrayref share_dir set as dist-type share"
);

# share_dir set to hashref w scalar
$dist->change_build_pl(
  {
    module_name         => $dist->name,
    license             => 'perl',
    share_dir           => { dist => 'share' },
  }
);
$dist->regen;
$mb = $dist->new_from_context;
is_deeply( $mb->share_dir, { dist => [ 'share' ] },
  "Hashref share_dir w/ scalar dist set as dist-type share"
);

# share_dir set to hashref w array
$dist->change_build_pl(
  {
    module_name         => $dist->name,
    license             => 'perl',
    share_dir           => { dist => [ 'share' ] },
  }
);
$dist->regen;
$mb = $dist->new_from_context;
is_deeply( $mb->share_dir, { dist => [ 'share' ] },
  "Hashref share_dir w/ arrayref dist set as dist-type share"
);

# Generate a module sharedir (scalar)
$dist->change_build_pl(
  {
    module_name         => $dist->name,
    license             => 'perl',
    share_dir           => { 
      dist => 'share',
      module => { $dist->name =>  'other'  },
    },
  }
);
$dist->regen;
$mb = $dist->new_from_context;
is_deeply( $mb->share_dir, 
  { dist => [ 'share' ], 
    module => { $dist->name => ['other']  },
  },
  "Hashref share_dir w/ both dist and module shares (scalar-form)"
);

# Generate a module sharedir (array)
$dist->change_build_pl(
  {
    module_name         => $dist->name,
    license             => 'perl',
    share_dir           => { 
      dist => [ 'share' ],
      module => { $dist->name =>  ['other']  },
    },
  }
);
$dist->regen;
$mb = $dist->new_from_context;
is_deeply( $mb->share_dir, 
  { dist => [ 'share' ], 
    module => { $dist->name => ['other']  },
  },
  "Hashref share_dir w/ both dist and module shares (array-form)"
);




