# -*- perl -*-

$| = 1;

my($testNum) = 0;

sub Test($) {
    my($ok) = shift;
    ++$testNum; print(($ok ? "" : "not "), "ok $testNum\n");
    $ok;
}

print "1..43\n";
require SQL::Statement;

$@ = '';
my($sth) = eval { SQL::Statement->new(undef) };
Test($@ =~ /parse/i);

$sth = SQL::Statement->new("CREATE TABLE foo (id INTEGER, name CHAR(64)"
			    . " PRIMARY KEY (id))");
Test(ref($sth));
Test($sth->command() eq 'CREATE');
Test($sth->tables() == 1);
Test($sth->tables(0)->name() eq 'foo');
Test($sth->columns() == 2);
Test($sth->columns(0)->table() eq 'foo');
Test($sth->columns(0)->name() eq 'id');
Test($sth->columns(1)->table() eq 'foo');
Test($sth->columns(1)->name() eq 'name');

$sth = SQL::Statement->new("SELECT a, * FROM foo WHERE (id > 2)"
			   . " AND (NOT(a LIKE '%a') OR a IS NULL)");
Test(ref($sth));
Test($sth->command() eq 'SELECT');
Test($sth->columns() == 2);
Test($sth->columns(0)->table() eq 'foo');
Test($sth->columns(0)->name() eq 'a')
    or printf("Expected column 'a', got %s\n", $sth->columns(0)->name());
Test($sth->columns(1)->table() eq 'foo');
Test($sth->columns(1)->name() eq '*');
Test($sth->tables() == 1);
Test($sth->tables(0)->name() eq 'foo');
Test($sth->where());
Test($sth->where->neg() == 0);
Test($sth->where->op() eq 'AND');
my($arg1, $arg2);
Test(ref($arg1 = $sth->where->arg1()) eq 'SQL::Statement::Op');
Test(ref($arg2 = $sth->where->arg2()) eq 'SQL::Statement::Op');
Test($arg1->neg() == 0);
Test($arg1->op() eq '>');
Test($arg1->arg1()->name eq 'id')
    or print "Expected 'id', got " . $arg1->arg1()->name() . "\n";
Test($arg1->arg1()->table() eq 'foo')
    or print "Expected undef, got " . $arg1->arg1()->table() . "\n";
Test($arg1->arg2() == 2)
    or print "Expected 2, got " . $arg1->arg2() . "\n";
Test($arg2->neg() == 0);
Test($arg2->op() eq 'OR');
Test(ref($arg2->arg1()) eq 'SQL::Statement::Op');
Test(ref($arg2->arg2()) eq 'SQL::Statement::Op');
Test($arg2->arg1()->neg());
Test($arg2->arg1()->op() eq 'LIKE');
Test($arg2->arg1()->arg1->name() eq 'a');
Test($arg2->arg1()->arg1->table() eq 'foo');
Test($arg2->arg1()->arg2 eq '%a');
Test($arg2->arg2()->neg() == 0);
Test($arg2->arg2()->op() eq 'IS');
Test($arg2->arg2()->arg1()->name() eq 'a')
    or print "Expected 'a', got '" . $arg2->arg2()->arg1() . "\n";
Test($arg2->arg2()->arg1()->table() eq 'foo')
    or print "Expected undef, got '" . $arg2->arg2()->arg1() . "\n";
Test(!defined($arg2->arg2()->arg2()));
