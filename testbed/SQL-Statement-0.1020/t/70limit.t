# -*- perl -*-

use strict;
use SQL::Statement ();


$| = 1;
$^W = 1;


my($testNum) = 0;

sub Test($) {
  my($ok) = shift;
  ++$testNum; print(($ok ? "" : "not "), "ok $testNum\n");
  $ok;
}


print "1..10\n";

my($parser);
$parser = SQL::Parser->new('Ansi');
my($stmt1, $stmt2,$stmt3,$limit1,$limit2,$limit3);

Test($stmt1 = SQL::Statement->new("SELECT * FROM foo limit 5", $parser));
Test($stmt2 = SQL::Statement->new("SELECT * FROM foo limit 2,10", $parser));
Test($stmt3 = SQL::Statement->new("SELECT * FROM foo", $parser));

Test($limit1 = $stmt1->limit());
Test($limit2 = $stmt2->limit());
Test(! defined ( $limit3 = $stmt3->limit() ) );

Test($limit1->offset() == 0)
    || print("offset = ", $limit1->offset(), ", expected 0\n");
Test($limit1->limit() == 5)
    || print("limit = ", $limit1->limit(), ", expected 5\n");

Test($limit2->offset() == 2)
    || print("offset = ", $limit2->offset(), ", expected 2\n");
Test($limit2->limit() == 10)
    || print("limit = ", $limit2->limit(), ", expected 10\n");

