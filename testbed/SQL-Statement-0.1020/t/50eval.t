# -*- perl -*-

use strict;
use SQL::Statement ();
use SQL::Eval ();


$| = 1;
$^W = 1;


package main;

sub ArrEq {
    my($arr1, $arr2) = @_;
    if (@$arr1 != @$arr2) {
	printf("Mismatch in number of rows, %d vs. %d\n",
	       scalar(@$arr1), scalar(@$arr2));
	return 0;
    }
    my($elem1, $elem2, $i);
    $i = 0;
    while (@$arr1) {
	$elem1 = shift @$arr1;
	$elem2 = shift @$arr2;
	if (ref($elem1)) {
	    if (!ref($elem2)) {
		printf("Mismatch in type: ref vs. scalar\n");
		return 0;
	    }
	    if (!ArrEq($elem1, $elem2)) {
		printf("Mismatch in row $i detected.\n");
		return 0;
	    }
	} else {
	    if (ref($elem2)) {
		printf("Mismatch in type: scalar vs. ref\n");
		return 0;
	    }
	    if (defined($elem1)) {
		if (defined($elem2)) {
		    if ($elem1 ne $elem2) {
			printf("Mismatch: $elem1 vs. $elem2\n");
			return 0;
		    }
		} else {
		    printf("Mismatch: $elem1 vs. undef\n");
		    return 0;
		}
	    } else {
		if (defined($elem2)) {
		    printf("Mismatch: $elem1 vs. undef\n");
		    return 0;
		}
	    }
	}
	++$i;
    }
    1;
}


############################################################################
#
# A subclass of Statement::SQL which implements tables as arrays of
# arrays.
#

package MyStatement;

@MyStatement::ISA = qw(SQL::Statement);

sub open_table ($$$$$) {
    my($self, $data, $tname, $createMode, $lockMode) = @_;
    my($table);
    if ($createMode) {
	if (exists($data->{$tname})) {
	    die "A table $tname already exists";
	}
	$table = $data->{$tname} = { 'DATA' => [],
				     'CURRENT_ROW' => 0,
				     'NAME' => $tname };
	bless($table, ref($self) . "::Table");
    } else {
	$table = $data->{$tname};
	$table->{'CURRENT_ROW'} = 0;
    }
    $table;
}

package MyStatement::Table;

@MyStatement::Table::ISA = qw(SQL::Eval::Table);

sub push_names ($$$) {
    my($self, $data, $names) = @_;
    $self->{'col_names'} = $names;
    my($colNums) = {};
    for (my $i = 0;  $i < @$names;  $i++) {
	$colNums->{$names->[$i]} = $i;
    }
    $self->{'col_nums'} = $colNums;
}

sub push_row ($$$) {
    my($self, $data, $row) = @_;
    my($currentRow) = $self->{'CURRENT_ROW'};
    $self->{'CURRENT_ROW'} = $currentRow+1;
    $self->{'DATA'}->[$currentRow] = $row;
}

sub fetch_row ($$$) {
    my($self, $data, $row) = @_;
    my($currentRow) = $self->{'CURRENT_ROW'};
    if ($currentRow >= @{$self->{'DATA'}}) {
	return undef;
    }
    $self->{'CURRENT_ROW'} = $currentRow+1;
    $self->{'row'} = $self->{'DATA'}->[$currentRow];
}

sub seek ($$$$) {
    my($self, $data, $pos, $whence) = @_;
    my($currentRow) = $self->{'CURRENT_ROW'};
    if ($whence == 0) {
	$currentRow = $pos;
    } elsif ($whence == 1) {
	$currentRow += $pos;
    } elsif ($whence == 2) {
	$currentRow = @{$self->{'DATA'}} + $pos;
    } else {
	die $self . "->seek: Illegal whence argument ($whence)";
    }
    if ($currentRow < 0) {
	die "Illegal row number: $currentRow";
    }
    $self->{'CURRENT_ROW'} = $currentRow;
}

sub truncate ($$) {
    my($self, $data) = @_;
    $#{$self->{'DATA'}} = $self->{'CURRENT_ROW'} - 1;
}

sub drop ($$) {
    my($self, $data) = @_;
    delete $data->{$self->{'NAME'}};
    return 1;
}


############################################################################


package main;

my($testNum) = 0;

sub Test($) {
    my($ok) = shift;
    ++$testNum; print(($ok ? "" : "not "), "ok $testNum\n");
    $ok;
}


print "1..130\n";

my($parser);
Test($parser = SQL::Parser->new('Ansi'));
my($stmt, $db);
$db = {};
Test($stmt = MyStatement->new("CREATE TABLE foo (id INT, name CHAR(64))",
			      $parser));
Test($stmt->execute($db));
Test(exists($db->{'foo'}));
Test(ref($db->{'foo'}) eq 'MyStatement::Table');
Test($db->{'foo'}->col_names()->[0] eq 'id');
Test($db->{'foo'}->col_names()->[1] eq 'name');
Test($db->{'foo'}->column_num('id') eq 0);
Test($db->{'foo'}->column_num('name') eq 1);
Test(!defined($db->{'foo'}->column_num('nosuchcolumn')));

print "Inserting some data.\n";
Test($stmt = MyStatement->new("INSERT INTO foo VALUES (?, ?)", $parser));
Test($stmt->execute($db, [1, 'Tim Bunce']));
Test($stmt = MyStatement->new("INSERT INTO foo (id, name) VALUES (?, ?)",
			      $parser));
Test($stmt->execute($db, [3, 'Jonathan Leffler']));
Test($stmt = MyStatement->new("INSERT INTO foo (name, id) VALUES (?, ?)",
			      $parser));
Test($stmt->execute($db, ['Jochen Wiedmann', 4]));
Test($stmt->execute($db, ['Andreas Koenig', 2]));
Test(@{$db->{'foo'}->{'DATA'}} == 4);


print "Retrieving the same data, ordered by id.\n";
Test($stmt = MyStatement->new("SELECT * FROM foo ORDER BY id"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'},
	   [ [ 1, 'Tim Bunce' ],
	     [ 2, 'Andreas Koenig' ],
	     [ 3, 'Jonathan Leffler' ],
	     [ 4, 'Jochen Wiedmann' ] ]));

print "Testing LIKE and CLIKE\n";
print "LIKE '%a%'\n";
Test($stmt = MyStatement->new("SELECT * FROM foo WHERE name LIKE '%a%'"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'},
	   [ [ 3, 'Jonathan Leffler' ],
	     [ 4, 'Jochen Wiedmann' ],
	     [ 2, 'Andreas Koenig' ] ]));
print "CLIKE '%a%'\n";
Test($stmt = MyStatement->new("SELECT * FROM foo WHERE name CLIKE '%a%'"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'},
	   [ [ 3, 'Jonathan Leffler' ],
	     [ 4, 'Jochen Wiedmann' ],
	     [ 2, 'Andreas Koenig' ] ]));
print "LIKE 'a%'\n";
Test($stmt = MyStatement->new("SELECT * FROM foo WHERE name LIKE 'a%'"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'}, [ ]));
print "CLIKE 'a%'\n";
Test($stmt = MyStatement->new("SELECT * FROM foo WHERE name CLIKE 'a%'"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'}, [ [ 2, 'Andreas Koenig' ] ]));
print "LIKE '%wied%'\n";
Test($stmt = MyStatement->new("SELECT * FROM foo WHERE name LIKE '%wied%'"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'}, [ ]));
print "CLIKE '%wied%'\n";
Test($stmt = MyStatement->new("SELECT * FROM foo WHERE name CLIKE '%wied%'"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'}, [ [ 4, 'Jochen Wiedmann' ] ]));
print "LIKE '%Wied%'\n";
Test($stmt = MyStatement->new("SELECT * FROM foo WHERE name LIKE '%Wied%'"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'}, [ [ 4, 'Jochen Wiedmann' ] ]));
print "CLIKE '%Wied%'\n";
Test($stmt = MyStatement->new("SELECT * FROM foo WHERE name CLIKE '%wied%'"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'}, [ [ 4, 'Jochen Wiedmann' ] ]));


print "Selecting by column names.\n";
Test($stmt = MyStatement->new("SELECT name, id FROM foo ORDER BY id"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'},
	   [ [ 'Tim Bunce', 1 ],
	     [ 'Andreas Koenig', 2 ],
	     [ 'Jonathan Leffler', 3 ],
	     [ 'Jochen Wiedmann', 4 ] ]));

print "Selecting names only, ordered by name.\n";
Test($stmt = MyStatement->new("SELECT name FROM foo ORDER BY name DESC"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'},
	   [ [ 'Tim Bunce' ],
	     [ 'Jonathan Leffler' ],
	     [ 'Jochen Wiedmann' ],
	     [ 'Andreas Koenig' ] ]));

print "Selecting names only, ordered by id, ascending.\n";
Test($stmt = MyStatement->new("SELECT name FROM foo ORDER BY id"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'},
	   [ [ 'Tim Bunce' ],
	     [ 'Andreas Koenig' ],
	     [ 'Jonathan Leffler' ],
	     [ 'Jochen Wiedmann' ] ]));

print "Selecting names only, ordered by id, descending.\n";
Test($stmt = MyStatement->new("SELECT name FROM foo ORDER BY id DESC"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'},
	   [ [ 'Jochen Wiedmann' ],
	     [ 'Jonathan Leffler' ],
	     [ 'Andreas Koenig' ],
	     [ 'Tim Bunce' ] ]));


Test($stmt = MyStatement->new("SELECT id FROM foo WHERE id > 2 ORDER BY id"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'},
	   [ [ 3 ], [4 ] ]));

Test($stmt = MyStatement->new("SELECT id FROM foo WHERE id > 2 OR name = 'Tim Bunce' ORDER BY id"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'},
	   [ [ 1 ], [ 3 ], [4 ] ]));

Test($stmt = MyStatement->new("UPDATE foo SET id = 5 WHERE id > 2"));
Test($stmt->execute($db));
Test($stmt = MyStatement->new("SELECT * FROM foo WHERE id > 1 ORDER BY id DESC, name"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'},
	   [ [ 5, 'Jochen Wiedmann' ],
	     [ 5, 'Jonathan Leffler' ],
	     [ 2, 'Andreas Koenig' ] ]));

Test($stmt = MyStatement->new("DELETE FROM foo WHERE name = 'Jochen Wiedmann'"));
Test($stmt->execute($db));
Test($stmt = MyStatement->new("SELECT * FROM foo ORDER BY id"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'},
	   [ [ 1, 'Tim Bunce' ],
	     [ 2, 'Andreas Koenig' ],
	     [ 5, 'Jonathan Leffler' ] ]));

Test($stmt = MyStatement->new("DROP TABLE foo"));
Test($stmt->execute($db));
Test($stmt = MyStatement->new("SELECT * FROM foo ORDER BY id"));
$@ = '';
eval { $stmt->execute(); };
Test($@);


Test($stmt = MyStatement->new("CREATE TABLE foo (n1 INT, n2 INT,"
			      . " s1 CHAR(64), s2 CHAR(64))", $parser));
Test($stmt->execute($db));
my @rows = (["1", "-01", "a", "a"],
	    ["3", "2", "c", "b"],
	    ["2", "-4", "b", "d"],
	    ["4", "04", "d", "c"]);
Test($stmt = MyStatement->new("INSERT INTO foo (n1, n2, s1, s2)"
			      . " VALUES (?, ?, ?, ?)", $parser));
my $row;
foreach $row (@rows) {
    Test($stmt->execute($db, $row));
}

Test($stmt = MyStatement->new("SELECT n1, n2 FROM foo WHERE n1 = n2"));
Test($stmt->execute($db));
#Test(ArrEq($stmt->{'data'},
#	   [ [ "4", "04" ] ]));


print "Joel's stuff...\n";
Test($stmt = MyStatement->new("DROP TABLE foo"));
Test($stmt->execute($db));
Test($stmt = MyStatement->new("CREATE TABLE foo (name CHAR(64))",
                              $parser));
Test($stmt->execute($db));
Test($stmt = MyStatement->new("INSERT INTO foo VALUES (?)", $parser));
Test($stmt->execute($db, ['Tim Bunce']));
Test($stmt->execute($db, ['Jochen Wiedmann']));
Test($stmt->execute($db, ['Joel Meulenberg']));
Test($stmt = MyStatement->new("SELECT * FROM foo WHERE name LIKE '%berg'"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'}, [ ['Joel Meulenberg' ] ]));
Test($stmt = MyStatement->new("SELECT * FROM foo WHERE name LIKE '%ber'"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'}, []));
Test($stmt = MyStatement->new("SELECT * FROM foo WHERE name LIKE 'Joel Meu'"));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'}, []));


print "IS NULL stuff...\n";
Test($stmt = MyStatement->new("CREATE TABLE nulls (id INTEGER,"
			      . " name VARCHAR(64))", $parser));
Test($stmt->execute($db));
Test($stmt = MyStatement->new("INSERT INTO nulls VALUES (?, ?)", $parser));
Test($stmt->execute($db, [1, 'Tim Bunce']));
Test($stmt->execute($db, [2, undef]));
Test($stmt->execute($db, [3, 'Andreas König']));
Test($stmt->execute($db, [4, undef]));

Test($stmt = MyStatement->new("SELECT * FROM nulls WHERE name IS NULL",
			      $parser));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'}, [[2, undef], [4, undef]]));

Test($stmt = MyStatement->new("SELECT * FROM nulls WHERE name IS NOT NULL",
			      $parser));
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'}, [[1, 'Tim Bunce'], [3, 'Andreas König']]));


print "DISTINCT stuff ...\n";
Test($stmt = MyStatement->new("CREATE TABLE cars (id INTEGER, company VARCHAR(64), type VARCHAR(64), color VARCHAR(64))", $parser));
Test($stmt->execute($db));
Test($stmt = MyStatement->new("INSERT INTO cars VALUES (?, ?, ?, ?)", $parser));
Test($stmt->execute($db, [1, "Mercedes", "C-Klasse", "silver"]));
Test($stmt->execute($db, [2, "BMW", "316i", "white"]));
Test($stmt->execute($db, [3, "Ford", "Escort XR3i", "blue"]));
Test($stmt->execute($db, [4, "Ford", "Mondeo XR3i", "red"]));
Test($stmt->execute($db, [5, "Mercedes", "E-Klasse", "silver"]));
Test($stmt = MyStatement->new("SELECT company, color FROM cars"));
Test(!$stmt->distinct());
Test($stmt = MyStatement->new("SELECT DISTINCT company, color FROM cars ORDER BY company", $parser));
Test($stmt->distinct());
Test($stmt->execute($db));
Test(ArrEq($stmt->{'data'},
	   [["BMW", "white"],
	    ["Ford", "blue"],
	    ["Ford", "red"],
	    ["Mercedes", "silver"]]));

