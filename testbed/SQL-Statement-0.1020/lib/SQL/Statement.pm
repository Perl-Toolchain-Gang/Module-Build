# -*- perl -*-

require 5.004;
use strict;

use DynaLoader ();
use SQL::Eval ();


package SQL::Statement;

use vars qw($VERSION @ISA);

$VERSION = '0.1020';
@ISA = qw(DynaLoader);

bootstrap SQL::Statement $VERSION;


sub execute ($$;$) {
    my($self, $data, $params) = @_;
    my($table, $msg);
    my($command) = $self->command();

    ($self->{'NUM_OF_ROWS'}, $self->{'NUM_OF_FIELDS'},
     $self->{'data'}) = $self->$command($data, $params);
    delete $self->{'tables'};  # Force closing the tables
    $self->{'NUM_OF_ROWS'} || '0E0';
}

sub open_tables ($$$$) {
    my($self, $data, $createMode, $lockMode) = @_;
    my($tables) = {};
    my($table);
    foreach $table ($self->tables()) {
	my($tname) = $table->name();
	if (!($tables->{$tname}
	      = $self->open_table($data, $tname, $createMode, $lockMode))) {
	    return undef;
	}
    }
    SQL::Eval->new({'tables' => $tables});
}

sub verify_columns ($$$) {
    my($self, $eval, $data) = @_;
    my($column, $tbl, $col);
    foreach $column ($self->val()) {
	if (ref($column)  &&  $column->isa("SQL::Statement::Column")) {
	    ($tbl, $col) = ($column->table(), $column->name());
	    if ($col ne '*'  &&
		!defined($eval->table($tbl)->column_num($col))) {
		die "Unknown column: $tbl.$col";
	    }
	}
    }
}


sub CREATE ($$$) {
    my($self, $data, $params) = @_;
    my($eval) = $self->open_tables($data, 1, 1);
    $eval->params($params);
    my($row) = [];
    my($col);
    my($table) = $eval->table($self->tables(0)->name());
    foreach $col ($self->columns()) {
	push(@$row, $col->name());
    }
    $table->push_names($data, $row);
    (0, 0);
}

sub DROP ($$$) {
    my($self, $data, $params) = @_;
    my($eval) = $self->open_tables($data, 0, 1);
    $eval->params($params);
    my($table) = $eval->table($self->tables(0)->name());
    $table->drop($data);
    (-1, 0);
}

sub INSERT ($$$) {
    my($self, $data, $params) = @_;
    my($eval) = $self->open_tables($data, 0, 1);
    $eval->params($params);
    $self->verify_columns($eval, $data);
    my($table) = $eval->table($self->tables(0)->name());
    $table->seek($data, 0, 2);
    my($array) = [];
    my($val, $col, $i);
    my($columns) = $table->{'colNums'};
    my($cNum) = scalar($self->columns());
    if ($cNum) {
	# INSERT INTO $table (row, ...) VALUES (value, ...)
	for ($i = 0;  $i < $cNum;  $i++) {
	    $col = $self->columns($i);
	    $val = $self->row_values($i);
	    if (ref($val) eq 'SQL::Statement::Param') {
		$val = $eval->param($val->num());
	    }
	    $array->[$table->column_num($col->name())] = $val;
	}
    } else {
	# INSERT INTO $table VALUES (value, ...)
	$cNum = scalar($self->row_values());
	for ($i = 0;  $i < $cNum;  $i++) {
	    $val = $self->row_values($i);
	    if (ref($val) eq 'SQL::Statement::Param') {
		$val = $eval->param($val->num());
	    }
	    $array->[$i] = $val;
	}
    }
    $table->push_row($data, $array);
    (1, 0);
}

sub UPDATE ($$$) {
    my($self, $data, $params) = @_;
    my($eval) = $self->open_tables($data, 0, 1);
    $eval->params($params);
    $self->verify_columns($eval, $data);
    my($table) = $eval->table($self->tables(0)->name());
    my($affected) = 0;
    my(@rows, $array, $val, $col, $i);
    while ($array = $table->fetch_row($data)) {
	if ($self->eval_where($eval)) {
	    for ($i = 0;  $i < $self->columns();  $i++) {
		$col = $self->columns($i);
		$val = $self->row_values($i);
		if (ref($val) eq 'SQL::Statement::Param') {
		    $val = $eval->param($val->num());
		}
		$array->[$table->column_num($col->name())] = $val;
	    }
	    ++$affected;
	}
	push(@rows, $array);
    }
    $table->seek($data, 0, 0);
    foreach $array (@rows) {
	$table->push_row($data, $array);
    }
    $table->truncate($data);
    ($affected, 0);
}

sub DELETE ($$$) {
    my($self, $data, $params) = @_;
    my($eval) = $self->open_tables($data, 0, 1);
    $eval->params($params);
    $self->verify_columns($eval, $data);
    my($table) = $eval->table($self->tables(0)->name());
    my($affected) = 0;
    my(@rows, $array);
    while ($array = $table->fetch_row($data)) {
	if ($self->eval_where($eval)) {
	    ++$affected;
	} else {
	    push(@rows, $array);
	}
    }
    $table->seek($data, 0, 0);
    foreach $array (@rows) {
	$table->push_row($data, $array);
    }
    $table->truncate($data);
    ($affected, 0);
}

sub SELECT ($$) {
    my($self, $data, $params) = @_;
    my($eval) = $self->open_tables($data, 0, 0);
    $eval->params($params);
    $self->verify_columns($eval, $data);
    my $tableName = $self->tables(0)->name();
    my $table = $eval->table($tableName);
    my $rows = [];

    # In a loop, build the list of columns to retrieve; this will be
    # used both for fetching data and ordering.
    my($cList, $col, $tbl, $ar, $i, $c);
    my $numFields = 0;
    my %columns;
    my @names;
    foreach my $column ($self->columns()) {
	if (ref($column) eq 'SQL::Statement::Param') {
	    my $val = $eval->param($column->num());
	    if ($val =~ /(.*)\.(.*)/) {
		$col = $1;
		$tbl = $2;
	    } else {
		$col = $val;
		$tbl = $tableName;
	    }
	} else {
	    ($col, $tbl) = ($column->name(), $column->table());
	}
	if ($col eq '*') {
	    $ar = $table->col_names();
	    for ($i = 0;  $i < @$ar;  $i++) {
		my $cName = $ar->[$i];
		$columns{$tbl}->{$cName} = $numFields++;
		$c = SQL::Statement::Column->new({'table' => $tableName,
						  'column' => $cName});
		push(@$cList, $i);
		push(@names, $cName);
	    }
	} else {
	    $columns{$tbl}->{$col} = $numFields++;
	    push(@$cList, $table->column_num($col));
	    push(@names, $col);
	}
    }
    $self->{'NAME'} = \@names;

    my @order_by = $self->order();
    my @extraSortCols;
    my $distinct = $self->distinct();
    if ($distinct) {
	# Silently extend the ORDER BY clause to the full list of
	# columns.
	my %ordered_cols;
	foreach my $column (@order_by) {
	    ($col, $tbl) = ($column->column(), $column->table());
	    $ordered_cols{$tbl}->{$col} = 1;
	}
	while (my($tbl, $cref) = each %columns) {
	    foreach my $col (keys %$cref) {
		if (!$ordered_cols{$tbl}->{$col}) {
		    $ordered_cols{$tbl}->{$col} = 1;
		    push(@order_by,
			 SQL::Statement::Order->new
			 ('col' => SQL::Statement::Column->new
			  ({'table' => $tbl,
			    'column' => $col}),
			  'desc' => 0));
		}
	    }
	}
    }
    if (@order_by) {
	my $nFields = $numFields;
	# It is possible that the user gave an ORDER BY clause with columns
	# that are not part of $cList yet. These columns will need to be
	# present in the array of arrays for sorting, but will be stripped
	# off later.
	foreach my $column (@order_by) {
	    ($col, $tbl) = ($column->column(), $column->table());
	    next if exists($columns{$tbl}->{$col});
	    push(@extraSortCols, $table->column_num($col));
	    $columns{$tbl}->{$col} = $nFields++;
	}
    }

    while (my $array = $table->fetch_row($data)) {
	if ($self->eval_where($eval)) {
	    # Note we also include the columns from @extraSortCols that
	    # have to be ripped off later!
	    my @row = map { $array->[$_] } (@$cList, @extraSortCols);
	    push(@$rows, \@row);
	}
    }

    if (@order_by) {
	my @sortCols = map {
	    ($columns{$_->table()}->{$_->column()}, $_->desc())
	} @order_by;
	my($c, $d, $colNum, $desc);
	my $sortFunc = sub {
	    my $result;
	    $i = 0;
	    do {
		$colNum = $sortCols[$i++];
		$desc = $sortCols[$i++];
		$c = $a->[$colNum];
		$d = $b->[$colNum];
		if (!defined($c)) {
		    $result = defined $d ? -1 : 0;
		} elsif (!defined($d)) {
		    $result = 1;
		} elsif ($c =~ /^\s*[+-]?\s*\.?\s*\d/  &&
			 $d =~ /^\s*[+-]?\s*\.?\s*\d/) {
		    $result = ($c <=> $d);
		} else {
		    $result = $c cmp $d;
		}
		if ($desc) {
		    $result = -$result;
		}
	    } while (!$result  &&  $i < @sortCols);
	    $result;
	};
	if ($distinct) {
	    my $prev;
	    @$rows = map {
		if ($prev) {
		    $a = $_;
		    $b = $prev;
		    if (&$sortFunc() == 0) {
			();
		    } else {
			$prev = $_;
		    }
		} else {
		    $prev = $_;
		}
	    } ($] > 5.00504 ?
	       sort $sortFunc @$rows :
	       sort { &$sortFunc } @$rows);
	} else {
	    @$rows = $] > 5.00504 ?
		(sort $sortFunc @$rows) :
		(sort { &$sortFunc } @$rows)
	}

	# Rip off columns that have been added for @extraSortCols only
	if (@extraSortCols) {
	    foreach my $row (@$rows) {
		splice(@$row, $numFields, scalar(@extraSortCols));
	    }
	}
    }

    (scalar(@$rows), $numFields, $rows);
}


package SQL::Statement::Column;

sub new ($$) {
    my($class, $attr) = @_;
    bless($attr, (ref($class) || $class));
    $attr;
}
sub table ($) { shift->{'table'}; }
sub name ($) { shift->{'column'}; }


package SQL::Statement::Table;

sub name ($) { shift->{'table'}; }


package SQL::Statement::Ident;

sub id ($) { shift->{'id'}; }


package SQL::Statement::Op;

sub neg ($) { shift->{'neg'}; }
sub op ($) { SQL::Statement->op(shift->{'op'}); }
sub arg1 ($) { my($self) = shift; $self->{'stmt'}->val($self->{'arg1'}); }
sub arg2 ($) { my($self) = shift; $self->{'stmt'}->val($self->{'arg2'}); }


package SQL::Statement::Param;

sub num ($) { shift->{'num'}; }


package SQL::Statement::Order;

sub new ($$) {
    my $proto = shift;
    my $self = {@_};
    bless($self, (ref($proto) || $proto));
}
sub table ($) { shift->{'col'}->table(); }
sub column ($) { shift->{'col'}->name(); }
sub desc ($) { shift->{'desc'}; }


package SQL::Statement::Limit;

sub new ($$) {
    my $proto = shift;
    my $self = {@_};
    bless($self, (ref($proto) || $proto));
}
sub limit ($) { shift->{'limi'}; }
sub offset ($) { shift->{'off'}; }


package SQL::Parser;

sub new ($;$$) {
    my($class, $name, $attr) = @_;
    my($self) = $class->dup($name);
    if ($self  &&  $attr) {
	my($set, $setVal, $feature, $featureVal);
	while (($set, $setVal) = each %$attr) {
	    while (($feature, $featureVal) = each %$setVal) {
		$self->feature($set, $feature, $featureVal);
	    }
	}
    }
    $self;
}

1;


__END__

=head1 NAME

SQL::Statement - SQL parsing and processing engine

=head1 SYNOPSIS

    require SQL::Statement;

    # Create a parser
    my($parser) = SQL::Parser->new('Ansi');

    # Parse an SQL statement
    $@ = '';
    my ($stmt) = eval {
        SQL::Statement->new("SELECT id, name FROM foo WHERE id > 1",
			    $parser);
    };
    if ($@) {
	die "Cannot parse statement: $@";
    }

    # Query the list of result columns;
    my $numColums = $stmt->columns();  # Scalar context
    my @columns = $stmt->columns();    # Array context
    # @columns now contains SQL::Statement::Column instances

    # Likewise, query the tables being used in the statement:
    my $numTables = $stmt->tables();   # Scalar context
    my @tables = $stmt->tables();      # Array context
    # @tables now contains SQL::Statement::Table instances

    # Query the WHERE clause; this will retrieve an
    # SQL::Statement::Op instance
    my $where = $stmt->where();


    # Evaluate the WHERE clause with concrete data, represented
    # by an SQL::Eval object
    my $result = $stmt->eval_where($eval);

    # Execute a statement:
    $stmt->execute($data, $params);


=head1 DESCRIPTION

For installing the module, see L<"INSTALLATION"> below.

The SQL::Statement module implements a small, abstract SQL engine. This
module is not usefull itself, but as a base class for deriving concrete
SQL engines. The implementation is designed to work fine with the
DBI driver DBD::CSV, thus probably not so well suited for a larger
environment, but I'd hope it is extendable without too much problems.

By parsing an SQL query you create an SQL::Statement instance. This
instance offers methods for retrieving syntax, for WHERE clause and
statement evaluation.


=head2 Creating a parser object

What's accepted as valid SQL, depends on the parser object. There is
a set of so-called features that the parsers may have or not. Usually
you start with a builtin parser:

    my $parser = SQL::Parser->new($name, [ \%attr ]);

Currently two parsers are builtin: The I<Ansi> parser implements a proper
subset of ANSI SQL. (At least I hope so. :-) The I<SQL::Statement> parser
is used by the DBD:CSV driver.

You can query or set individual features. Currently available are:

=over 8

=item create.type_blob

=item create.type_real

=item create.type_text

These enable the respective column types in a I<CREATE TABLE> clause.
They are all disabled in the I<Ansi> parser, but enabled in the
I<SQL::Statement> parser. Example:

=item select.join

This enables the use of multiple tables in a SELECT statement, for
example

  SELECT a.id, b.name FROM a, b WHERE a.id = b.id AND a.id = 2

=back

To enable or disable a feature, for example I<select.join>, use the
following:

  # Enable feature
  $parser->feature("select", "join", 1);
  # Disable feature
  $parser->feature("select", "join", 0);

Of course you can query features:

  # Query feature
  my $haveSelectJoin = $parser->feature("select", "join");

The C<new> method allows a shorthand for setting features. For example,
the following is equivalent to the I<SQL::Statement> parser:

  $parser = SQL::Statement->new('Ansi',
				{ 'create' => { 'type_text' => 1,
						'type_real' => 1,
						'type_blob' => 1 },
				  'select' => { 'join' => 0 }});


=head2 Parsing a query

A statement can be parsed with

    my $stmt = SQL::Statement->new($query, $parser);

In case of syntax errors or other problems, the method throws a Perl
exception. Thus, if you want to catch exceptions, the above becomes

    $@ = '';
    my $stmt = eval { SQL::Statement->new($query, $parser) };
    if ($@) { print "An error occurred: $@"; }

The accepted SQL syntax is restricted, though easily extendable. See
L<SQL syntax> below. See L<Creating a parser object> above.


=head2 Retrieving query information

The following methods can be used to obtain information about a
query:

=over 8

=item command

Returns the SQL command, currently one of I<SELECT>, I<INSERT>, I<UPDATE>,
I<DELETE>, I<CREATE> or I<DROP>, the last two referring to
I<CREATE TABLE> and I<DROP TABLE>. See L<SQL syntax> below. Example:

    my $command = $stmt->command();

=item columns

    my $numColumns = $stmt->columns();  # Scalar context
    my @columnList = $stmt->columns();  # Array context
    my($col1, $col2) = ($stmt->columns(0), $stmt->columns(1));

This method is used to retrieve column lists. The meaning depends on
the query command:

    SELECT $col1, $col2, ... $colN FROM $table WHERE ...
    UPDATE $table SET $col1 = $val1, $col2 = $val2, ...
        $colN = $valN WHERE ...
    INSERT INTO $table ($col1, $col2, ..., $colN) VALUES (...)

When used without arguments, the method returns a list of the
columns $col1, $col2, ..., $colN, you may alternatively use a
column number as argument. Note that the column list may be
empty, like in

    INSERT INTO $table VALUES (...)

and in I<CREATE> or I<DROP> statements.

But what does "returning a column" mean? It is returning an
SQL::Statement::Column instance, a class that implements the
methods C<table> and C<name>, both returning the respective
scalar. For example, consider the following statements:

    INSERT INTO foo (bar) VALUES (1)
    SELECT bar FROM foo WHERE ...
    SELECT foo.bar FROM foo WHERE ...

In all these cases exactly one column instance would be returned
with

    $col->name() eq 'bar'
    $col->table() eq 'foo'

=item tables

    my $tableNum = $stmt->tables();  # Scalar context
    my @tables = $stmt->tables();    # Array context
    my($table1, $table2) = ($stmt->tables(0), $stmt->tables(1));

Similar to C<columns>, this method returns instances of
C<SQL::Statement::Table>.  For I<UPDATE>, I<DELETE>, I<INSERT>,
I<CREATE> and I<DROP>, a single table will always be returned.
I<SELECT> statements can return more than one table, in case
of joins. Table objects offer a single method, C<name> which
returns the table name.

=item params

    my $paramNum = $stmt->params();  # Scalar context
    my @params = $stmt->params();    # Array context
    my($p1, $p2) = ($stmt->params(0), $stmt->params(1));

The C<params> method returns information about the input parameters
used in a statement. For example, consider the following:

    INSERT INTO foo VALUES (?, ?)

This would return two instances of SQL::Statement::Param. Param objects
implement a single method, C<$param->num()>, which retrieves the
parameter number. (0 and 1, in the above example). As of now, not very
usefull ... :-)

=item row_values

    my $rowValueNum = $stmt->row_values(); # Scalar context
    my @rowValues = $stmt->row_values();   # Array context
    my($rval1, $rval2) = ($stmt->row_values(0),
			  $stmt->row_values(1));

This method is used for statements like

    UPDATE $table SET $col1 = $val1, $col2 = $val2, ...
        $colN = $valN WHERE ...
    INSERT INTO $table (...) VALUES ($val1, $val2, ..., $valN)

to read the values $val1, $val2, ... $valN. It returns scalar values
or SQL::Statement::Param instances.

=item order

    my $orderNum = $stmt->order();   # Scalar context
    my @order = $stmt->order();      # Array context
    my($o1, $o2) = ($stmt->order(0), $stmt->order(1));

In I<SELECT> statements you can use this for looking at the ORDER
clause. Example:

    SELECT * FROM FOO ORDER BY id DESC, name

In this case, C<order> could return 2 instances of SQL::Statement::Order.
You can use the methods C<$o-E<gt>table()>, C<$o-E<gt>column()> and
C<$o-E<gt>desc()> to examine the order object.

=item limit

    my $l = $stmt->limit();
    if ($l) {
      my $offset = $l->offset();
      my $limit = $l->limit();
    }

In a SELECT statement you can use a C<LIMIT> clause to implement
cursoring:

    SELECT * FROM FOO LIMIT 5
    SELECT * FROM FOO LIMIT 5, 5
    SELECT * FROM FOO LIMIT 10, 5

These three statements would retrieve the rows 0..4, 5..9, 10..14
of the table FOO, respectively. If no C<LIMIT> clause is used, then
the method C<$stmt-E<gt>limit> returns undef. Otherwise it returns
an instance of SQL::Statement::Limit. This object has the methods
C<offset> and C<limit> to retrieve the index of the first row and
the maximum number of rows, respectively.

=item where

    my $where = $stmt->where();

This method is used to examine the syntax tree of the C<WHERE> clause.
It returns undef (if no WHERE clause was used) or an instance of
SQL::Statement::Op. The Op instance offers 4 methods:

=over 12

=item op

returns the operator, one of C<AND>, C<OR>, C<=>, C<E<lt>E<gt>>, C<E<gt>=>,
C<E<gt>>, C<E<lt>=>, C<E<lt>>, C<LIKE>, C<CLIKE> or C<IS>.

=item arg1

=item arg2

returns the left-hand and right-hand sides of the operator. This can be a
scalar value, an SQL::Statement::Param object or yet another
SQL::Statement::Op instance.

=item neg

returns a TRUE value, if the operation result must be negated after
evalution.

=back

To evaluate the I<WHERE> clause, fetch the topmost Op instance with
the C<where> method. Then evaluate the left-hand and right-hand side
of the operation, perhaps recursively. Once that is done, apply the
operator and finally negate the result, if required.

=back

To illustrate the above, consider the following WHERE clause:

    WHERE NOT (id > 2 AND name = 'joe') OR name IS NULL

We can represent this clause by the following tree:

              (id > 2)   (name = 'joe')
                     \   /
          NOT         AND
                         \      (name IS NULL)
                          \    /
                            OR

Thus the WHERE clause would return an SQL::Statement::Op instance with
the op() field set to 'OR'. The arg2() field would return another
SQL::Statement::Op instance with arg1() being the SQL::Statement::Column
instance representing id, the arg2() field containing the value undef
(NULL) and the op() field being 'IS'.

The arg1() field of the topmost Op instance would return an Op instance
with op() eq 'AND' and neg() returning TRUE. The arg1() and arg2()
fields would be Op's representing "id > 2" and "name = 'joe'".

Of course there's a ready-for-use method for WHERE clause evaluation:


=head2 Evaluating a WHERE clause

The WHERE clause evaluation depends on an object being used for
fetching parameter and column values. Usually this can be an
SQL::Eval object, but in fact it can be any object that supplies
the methods

    $val = $eval->param($paramNum);
    $val = $eval->column($table, $column);

See L<SQL::Eval> for a detailed description of these methods.
Once you have such an object, you can call a

    $match = $stmt->eval_where($eval);


=head2 Evaluating queries

So far all methods have been concrete. However, the interface for
executing and evaluating queries is abstract. That means, for using
them you have to derive a subclass from SQL::Statement that implements
at least certain missing methods and/or overwrites others. See the
C<test.pl> script for an example subclass.

Something that all methods have in common is that they simply throw
a Perl exception in case of errors.


=over 8

=item execute

After creating a statement, you must execute it by calling the C<execute>
method. Usually you put an eval statement around this call:

    $@ = '';
    my $rows = eval { $self->execute($data); };
    if ($@) { die "An error occurred!"; }

In case of success the method returns the number of affected rows or -1,
if unknown. Additionally it sets the attributes

    $self->{'NUM_OF_FIELDS'}
    $self->{'NUM_OF_ROWS'}
    $self->{'data'}

the latter being an array ref of result rows. The argument $data is for
private use by concrete subclasses and will be passed through to all
methods. (It is intentionally not implemented as attribute: Otherwise
we might well become self referencing data structures which could
prevent garbage collection.)


=item CREATE

=item DROP

=item INSERT

=item UPDATE

=item DELETE

=item SELECT

Called by C<execute> for doing the real work. Usually they create an
SQL::Eval object by calling C<$self-E<gt>open_tables()>, call
C<$self-E<gt>verify_columns()> and then do their job. Finally they return
the triple

    ($self->{'NUM_OF_ROWS'}, $self->{'NUM_OF_FIELDS'},
     $self->{'data'})

so that execute can setup these attributes. Example:

    ($self->{'NUM_OF_ROWS'}, $self->{'NUM_OF_FIELDS'},
     $self->{'data'}) = $self->SELECT($data);


=item verify_columns

Called for verifying the row names that are used in the statement.
Example:

    $self->verify_columns($eval, $data);


=item open_tables

Called for creating an SQL::Eval object. In fact what it returns
doesn't need to be derived from SQL::Eval, it's completely sufficient
to implement the same interface of methods. See L<SQL::Eval> for
details. The arguments C<$data>, C<$createMode> and C<$lockMode>
are corresponding to those of SQL::Eval::Table::open_table and
usually passed through. Example:

    my $eval = $self->open_tables($data, $createMode, $lockMode);

The eval object can be used for calling C<$self->verify_columns> or
C<$self->eval_where>.

=item open_table

This method is completely abstract and *must* be implemented by subclasses.
The default implementation of C<$self->open_tables> calls this method for
any table used by the statement. See the C<test.pl> script for an example
of imlplementing a subclass.

=back


=head1 SQL syntax

The SQL::Statement module is far away from ANSI SQL or something similar,
it is designed for implementing the DBD::CSV module. See L<DBD::CSV(3)>.

I do not want to give a formal grammar here, more an informal
description: Read the statement definition in sql_yacc.y, if you need
something precise.

The main lexical elements of the grammar are:

=over 8

=item Integers

=item Reals

Syntax obvious

=item Strings

Surrounded by either single or double quotes; some characters need to
be escaped with a backslash, in particular the backslash itself (\\),
the NUL byte (\0), Line feeds (\n), Carriage return (\r), and the
quotes (\' or \").

=item Parameters

Parameters represent scalar values, like Integers, Reals and Strings
do. However, their values are read inside Execute() and not inside
Prepare(). Parameters are represented by question marks (?).

=item Identifiers

Identifiers are table or column names. Syntactically they consist of
alphabetic characters, followed by an arbitrary number of alphanumeric
characters. Identifiers like SELECT, INSERT, INTO, ORDER, BY, WHERE,
... are forbidden and reserved for other tokens.

=back

What it offers is the following:

=head2 CREATE

This is the CREATE TABLE command:

    CREATE TABLE $table ( $col1 $type1, ..., $colN $typeN,
                          [ PRIMARY KEY ($col1, ... $colM) ] )

The column names are $col1, ... $colN. The column types can be
C<INTEGER>, C<CHAR(n)>, C<VARCHAR(n)>, C<REAL> or C<BLOB>. These
types are currently completely ignored. So is the (optional)
C<PRIMARY KEY> clause.

=head2 DROP

Very simple:

    DROP TABLE $table

=head2 INSERT

This can be

    INSERT INTO $table [ ( $col1, ..., $colN ) ]
        VALUES ( $val1, ... $valN )

=head2 DELETE

    DELETE FROM $table [ WHERE $where_clause ]

See L<SELECT> below for a decsription of $where_clause

=head2 UPDATE

    UPDATE $table SET $col1 = $val1, ... $colN = $valN
        [ WHERE $where_clause ]

See L<SELECT> below for a decsription of $where_clause

=head2 SELECT

    SELECT [DISTINCT] $col1, ... $colN FROM $table
        [ WHERE $where_clause ] [ ORDER BY $ocol1, ... $ocolM ]

The $where_clause is based on boolean expressions of the form
$val1 $op $val2, with $op being one of '=', '<>', '>', '<', '>=',
'<=', 'LIKE', 'CLIKE' or IS. You may use OR, AND and brackets to combine
such boolean expressions or NOT to negate them.


=head1 INSTALLATION

Like most other Perl modules, you simply do a

    perl Makefile.PL
    make		(nmake or dmake, if you are using Win32)
    make test		(Let me know, if any tests fail)
    make install

Known problems are:

=over 8

=item *

Some flavours of SCO Unix don't seem to have alloca() or something similar.
I recommend using gcc or egcs for compiling Perl and the SQL::Statement
module: Both compilers have a builtin alloca().

Another option could be to use external alloca.c, for example

  http://www.pu.informatik.th-darmstadt.de/FTP/pub/pu/alloca.c
  http://www.cs.purdue.edu/homes/young/src2www-example/alloca.c.html

I did test neither of them and cannot give detailed instructions for
including them into the SQL::Statement module. However, it should
be sufficient to compile alloca.c with the same instructions than,
for example, sql_yacc.c and finally repeat the linker command by
inserting alloca.o after sql_yacc.o.

Note that I cannot modify the sources to work without alloca(), as it is
the bison parser that's using alloca() and I don't have the bison generated
code in my hands.

My thanks to Theo Petersen, <theo@acsp.com>, for pointing out this problem
and the possible workarounds.

=back


=head1 INTERNALS

Internally the module is splitted into three parts:


=head2 Perl-independent C part

This part, contained in the files C<sql_yacc.y>, C<sql_data.h>,
C<sql_data.c> and C<sql_op.c>, is completely independent from Perl.
It might well be used from within another script language, Tcl say,
or from a true C application.

You probably ask, why Perl independence? Well, first of all, I
think this is a valuable target in itself. But the main reason was
the impossibility to use the Perl headers inside bison generated
code. The Perl headers export almost the complete Yacc interface
to XS, for whatever reason, thus redefining constants and structures
created by your own bison code. :-(


=head2 Perl-dependent C part

This is contained in C<Statement.xs>. The both C parts communicate via
a C structure sql_stmt_t. In fact, an SQL::Statement object is nothing
else than a pointer to such a structure. The XS calls columns(), Table(),
where(), ... do nothing more than fetching data from this structure
and converting it to Perl objects. See L<The sql_stmt_t structure>
below for details on the structure.


=head2 Perl part

Besides some stub functions for retrieving statement data, this is
mainly the query processing with the exception of WHERE clause
evaluation.


=head2 The sql_stmt_t structure

This structure is designed for optimal performance. A typical query
will be parsed with only 4 or 5 malloc() calls; in particular no
memory will be aquired for storing strings; only pointers into the
query string are used.

The statement stores its tokens in the values array. The array elements
are of type sql_val_t, a union, that can represent the most interesting
tokens; for example integers and reals are stored in the data.i and
data.d parts of the union, strings are stored in the data.str part,
columns in the data.col part and so on. Arrays are allocated in chunks
of 64 elements, thus a single malloc() will be usually sufficient for
allocating the complete array. Some types use pointers into the values
array: For example, operations are stored in an sql_op_t structure that
containes elements arg1 and arg2 which are pointers into the value
table, pointing to other operations or scalars. These pointers are
stored as indices, so that the array can be extended using realloc().

The sql_stmt_t structure contains other arrays: columns, tables,
rowvals, order, ... representing the data returned by the columns(),
tables(), row_values() and order() methods. All of these contain
pointers into the values array, again stored as integers.

Arrays are initialized with the _InitArray call in SQL_Statement_Prepare
and deallocated with _DestroyArray in SQL_Statement_Destroy. Array
elements are obtained by calling _AllocData, which returns an index.
The number -1 is used for errors or as a NULL value.


=head2 The WHERE clause evaluation

A WHERE clause is evaluated by calling SQL_Statement_EvalWhere(). This
function is in the Perl independent part, but it needs the possibility
to retrieve data from the Perl part, for example column or parameter
values. These values are retrieved via callbacks, stored in the
sql_eval_t structure. The field stmt->evalData points to such a
structure. Of course the calling method can extend the sql_eval_t
structure (like eval_where in Statement.xs does) to include private data
not used by SQL_Statement_EvalWhere.


=head2 Features

Different parsers are implemented via the sql_parser_t structure. This
is mainly a set of yes/no flags. If you'd like to add features, do
the following:

First of all, extend the sql_parser_t structure. If your feature is
part of a certain statement, place it into the statements section,
for example "select.join". Otherwise choose a section like "misc"
or "general". (There's no particular for the section design, but
structure never hurts.)

Second, add your feature to sql_yacc.y. If your feature needs to
extend the lexer, do it like this:

    if (FEATURE(misc, myfeature) {
	/*  Scan your new symbols  */
	...
    }

See the I<BOOL> symbol as an example.

If you need to extend the parser, do it like this:

    my_new_rule:
	/*  NULL, old behaviour, doesn't use my feature  */
        | my_feature
            { YFEATURE(misc, myfeature); }
    ;

Thus all parsers not having FEATURE(misc, myfeature) set will produce
a parse error here. Again, see the BOOL symbol for an example.

Third thing is to extend the builtin parsers. If they support your
feature, add a 1, otherwise a 0. Currently there are two builtin
parsers: The I<ansiParser> in sql_yacc.y and the sqlEvalParser in
Statement.xs.

Finally add support for your feature to the C<feature> method in
Statement.xs. That's it!


=head1 MULTITHREADING

The complete module code is reentrant. In particular the parser is
created with C<%pure_parser>. See L<bison(1)> for details on
reentrant parsers. That means, the module is ready for multithreading,
as long as you don't share handles between threads. Read-only handles,
for example parsers, can even be shared.

Statement handles cannot be shared among threads, at least not, if
you don't grant serialized access. Per-thread handles are always safe.


=head1 AUTHOR AND COPYRIGHT

This module is Copyright (C) 1998 by

    Jochen Wiedmann
    Am Eisteich 9
    72555 Metzingen
    Germany

    Email: joe@ispsoft.de
    Phone: +49 7123 14887

All rights reserved.

You may distribute this module under the terms of either the GNU
General Public License or the Artistic License, as specified in
the Perl README file. 


=head1 SEE ALSO

L<DBI(3)>, L<DBD::CSV(3)>

=cut
