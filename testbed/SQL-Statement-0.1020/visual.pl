# -*- perl -*-

require 5.004;
use strict;


require SQL::Statement;
require SQL::Eval;
require Benchmark;


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


if (! -d "output"  &&  ! mkdir "output", 0755) {
    die "Cannot create 'output' directory: $!";
}


my($i);
sub TimeMe ($$$$) {
    my($startMsg, $endMsg, $code, $count) = @_;
    printf("\n%s\n", $startMsg);
    my($t1) = Benchmark->new();
    $@ = '';
    eval {
	for ($i = 0;  $i < $count;  $i++) {
	    &$code;
	}
    };
    if ($@) {
	print "Test failed, message: $@\n";
    } else {
	my($td) = Benchmark::timediff(Benchmark->new(), $t1);
	my($dur) = $td->cpu_a;
	printf($endMsg, $count, $dur, $count / $dur);
	print "\n";
    }
}


# TimeMe("Testing empty loop speed ...",
#        "%d iterations in %.1f cpu+sys seconds (%d per sec)",
#        sub {
#        },
#     100000);


my($stmt, $db);
$db = {};
# my(@statements) = (
#     "CREATE TABLE foo (id INT, name CHAR(64), address CHAR(64))",
#     "INSERT INTO foo (id, name, address) VALUES (?, ?, ?)",
#     "SELECT id, name, address FROM foo WHERE id > 2 AND name LIKE 'a%'"
#     . " ORDER BY address",
#     "UPDATE foo SET name = ?, id = 7 WHERE id = 4"
# );
# TimeMe("Testing parsing speed ...",
#        "%d statements parsed in %.1f cpu+sys seconds (%d per sec)",
#        sub {
# 	   $stmt = MyStatement->new($statements[$i % 4]);
#        },
#     2000);

TimeMe("Testing CREATE/DROP TABLE speed ...",
       "%d tables in %.1f cpu+sys seconds (%d per sec)",
       sub {
	   $stmt = MyStatement->new("CREATE TABLE bench (id INTEGER, name"
				    . " CHAR(40), firstname CHAR(40),"
				    . " address CHAR(40), zip CHAR(10),"
				    . " city CHAR(40), email CHAR(40))");
	   $stmt->execute($db);
	   $stmt = MyStatement->new("DROP TABLE bench");
	   $stmt->execute($db);
       },
    500);

$stmt = MyStatement->new("CREATE TABLE bench (id INTEGER, name"
    . " CHAR(40), firstname CHAR(40),"
    . " address CHAR(40), zip CHAR(10),"
    . " city CHAR(40), email CHAR(40))");
$stmt->execute($db);
my(@vals) = (0 .. 499);
my($num);
TimeMe("Testing INSERT speed ...",
       "%d rows in %.1f cpu+sys seconds (%d per sec)",
       sub {
	   ($num) = splice(@vals, int(rand(@vals)), 1);
	   $stmt = MyStatement->new("INSERT INTO bench VALUES (?, 'Wiedmann',"
				    . " 'Jochen', 'Am Eisteich 9', '72555',"
				    . " 'Metzingen', 'joe\@ispsoft.de')");
	   $stmt->execute($db, [$num]);
       },
    500);

TimeMe("Testing SELECT speed ...",
       "%d single rows out of 500 in %.1f cpu+sys seconds (%.1f per sec)",
       sub {
	   $num = int(rand(500));
	   $stmt = MyStatement->new("SELECT * FROM bench WHERE id = $num");
	   $stmt->execute($db);
	   (@{$stmt->{'data'}} == 1)
	       or die "Expected 1 rows for id = $num, got "
		   . scalar($stmt->{'data'});
       },
    100);


TimeMe("Testing SELECT speed (multiple rows) ...",
       "%d times 100 rows out of 500 in %.1f cpu+sys seconds (%.1f per sec)",
       sub {
	   $num = int(rand(400));
	   $stmt = MyStatement->new("SELECT * FROM bench WHERE id >= $num"
				    . " AND id < " . ($num+100));
	   $stmt->execute($db);
	   (@{$stmt->{'data'}} == 100)
	       or die "Expected 100 rows for id = $num, got "
		   . scalar($stmt->{'data'})
       },
    100);
