use strict;
use lib 't/lib';
use MBTest;
use DistGen;

if (eval { require CPAN::Meta; CPAN::Meta->VERSION(2.142060) }) {
	plan('no_plan');
	require CPAN::Meta::YAML;
	require Parse::CPAN::Meta;
}
else {
	plan(skip_all => 'No or old CPAN::Meta');
}

# Ensure any Module::Build modules are loaded from correct directory
blib_load('Module::Build');

#--------------------------------------------------------------------------#
# Create test distribution
#--------------------------------------------------------------------------#

{
  my $dist = DistGen->new( 
    name => 'Simple::Name', 
    version => '0.01',
    license => 'perl'
  );

  $dist->regen;
  $dist->chdir_in;

  my $mb = $dist->new_from_context();
  isa_ok( $mb, "Module::Build" );
  is( $mb->license, 'perl',
    "license 'perl' is valid"
  );

  my $meta = $mb->get_metadata( fatal => 0 );
  
  is_deeply( $meta->{license} => [ 'perl_5' ], "META license will be 'perl'" );
  is_deeply( $meta->{resources}{license}, [ "http://dev.perl.org/licenses/" ], 
    "META license URL is correct" 
  );

}

{
  my $dist = DistGen->new( 
    name => 'Simple::Name', 
    version => '0.01',
    license => 'VaporWare'
  );

  $dist->regen;
  $dist->chdir_in;

  my $mb = $dist->new_from_context();
  isa_ok( $mb, "Module::Build" );
  is( $mb->license, 'VaporWare',
    "license 'VaporWare' is valid"
  );

  my $meta = $mb->get_metadata( fatal => 0 );
  
  is_deeply( $meta->{license} => [ 'unrestricted' ], "META license will be 'unrestricted'" );
  is_deeply( $meta->{resources}{license}, [ "http://example.com/vaporware/" ], 
    "META license URL is correct" 
  );

}

# Test with alpha number
# vim:ts=2:sw=2:et:sta:sts=2
