package Module::Build::Config;

use strict;
use warnings;
our $VERSION = '0.4231';
$VERSION = eval $VERSION;

use base 'ExtUtils::Config';

### DEPRECATED in favor of ExtUtils::Config ###

sub new {
  my ($pack, %args) = @_;
  my $self = $pack->SUPER::new($args{values});
  return bless $self, $pack;
}
