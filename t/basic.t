######################### We start with some black magic to print on failure.

BEGIN { $| = 1; print "1..1\n"; }
END {print "not ok 1\n" unless $loaded;}
use Module::Build;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

