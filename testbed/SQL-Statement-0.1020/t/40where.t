# -*- perl -*-

use strict;
require SQL::Statement;
require SQL::Eval;


$| = 1;
$^W = 1;


my($testNum) = 0;

sub Test($) {
    my($ok) = shift;
    ++$testNum; print(($ok ? "" : "not "), "ok $testNum\n");
    $ok;
}


print "1..24\n";

my($parser);
Test($parser = SQL::Parser->new('Ansi'));
my($stmt, $stmt2);
Test($stmt = SQL::Statement->new("SELECT * FROM foo WHERE id > ? AND"
				 . " (foo = 'a' OR NOT bar = 'b')", $parser));
Test($stmt2 = SQL::Statement->new("SELECT * FROM foo", $parser));

my($fooTable) = SQL::Eval::Table->new({ 'col_names' => ['id', 'bar', 'foo'],
					'col_nums' => { 'id' => 0,
							'bar' => 1,
							'foo' => 2 } });
Test($fooTable);
my($eval) = SQL::Eval->new({'params' => [],
			    'tables' =>
			    { 'foo' => $fooTable }});
Test($eval);
Test($eval->param(0, 1) == 1);
Test($eval->param(0) == 1);
Test(!$eval->param(1));

$fooTable->{'row'} = [ 0, 'd', 'c' ];
Test(!$stmt->eval_where($eval));
Test($stmt2->eval_where($eval));
$fooTable->{'row'} = [ 2, 'd', 'c' ];
Test($stmt->eval_where($eval)) or print "Expected TRUE value\n";
Test($stmt2->eval_where($eval));
$fooTable->{'row'} = [ 0, 'd', 'a' ];
Test(!$stmt->eval_where($eval));
Test($stmt2->eval_where($eval));
$fooTable->{'row'} = [ 2, 'd', 'a' ];
Test($stmt->eval_where($eval));
Test($stmt2->eval_where($eval));
$fooTable->{'row'} = [ 0, 'b', 'c' ];
Test(!$stmt->eval_where($eval));
Test($stmt2->eval_where($eval));
$fooTable->{'row'} = [ 2, 'b', 'c' ];
Test(!$stmt->eval_where($eval));
Test($stmt2->eval_where($eval));
$fooTable->{'row'} = [ 0, 'b', 'a' ];
Test(!$stmt->eval_where($eval));
Test($stmt2->eval_where($eval));
$fooTable->{'row'} = [ 2, 'b', 'a' ];
Test($stmt->eval_where($eval));
Test($stmt2->eval_where($eval));
