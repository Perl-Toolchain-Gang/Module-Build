use lib qw(lib);
use Module::Build;

my $b = new Module::Build;
$b->create(
	   module_name => 'Module::Build',
	  );
