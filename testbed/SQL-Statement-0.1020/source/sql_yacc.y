/* -*- C -*-
 */

%{

#include "sql_data.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#if defined(WIN32)
#define MSDOS		/* This symbol is used in bison generated code  */
#endif

#define FEATURE(a,b) (((sql_stmt_t*) stmt)->parser->a.b)
#define YFEATURE(a,b) if (!FEATURE(a,b)) { YYABORT; }

#define isalnum_(c) (isalnum(c) || c == '_')

%}

%union {
    int scalar_val;
    int bool_val;
    int int_val;
    double real_val;
    sql_string_t string_val;
    sql_ident_t ident_val;
    sql_param_t param;
    int column;
    int val;
    int operator;
    int null_val;
}

%{

#define YYPARSE_PARAM stmt
#define YYLEX_PARAM stmt
static int yyerror(const char* msg);
static int yyparse(void*stmt);
static int yylex(YYSTYPE* lvalp, void* s);


static int _AllocData(sql_stmt_t* stmt, sql_array_t* array);
static int _AllocString(sql_stmt_t* stmt, sql_string_t* str);
static int _AllocInteger(sql_stmt_t* stmt, int i);
static int _AllocReal(sql_stmt_t* stmt, double d);
static int _AllocOp(sql_stmt_t* stmt, sql_op_t* o);
static int _AllocNull(sql_stmt_t* stmt);
static int _AllocColumn(sql_stmt_t* stmt, sql_column_t* column);
static int _AllocColumnList(sql_stmt_t* stmt, sql_column_list_t* column);
static int _AllocTable(sql_stmt_t* stmt, sql_table_t* table);
static int _AllocTableList(sql_stmt_t* stmt, sql_table_list_t* table);
static int _AllocRowValList(sql_stmt_t* stmt, sql_rowval_list_t* rval);
static int _AllocParam(sql_stmt_t* stmt, sql_param_t* param);
static int _AllocOrderRow(sql_stmt_t* stmt, sql_order_t* o);

%}

%token <int_val>    INTEGERVAL
%token <string_val> STRING
%token <real_val>   REALVAL
%token <ident_val>  IDENT
%token <null_val>   NULLVAL
%token <param> PARAM

%token <operator> OPERATOR
%token <operator> IS
%left <operator> AND
%left <operator> OR

%token ERROR

%token INSERT
%token UPDATE
%token SELECT
%token DELETE
%token DROP
%token CREATE

%token ALL
%token DISTINCT
%token WHERE
%token ORDER
%token LIMIT
%token ASC
%token DESC
%token FROM
%token INTO
%token BY
%token VALUES
%token SET
%token NOT
%token NULLVAL
%token TABLE
%token CHAR
%token VARCHAR
%token REAL
%token INTEGER
%token PRIMARY
%token KEY
%token BLOB
%token TEXT

%type <bool_val> conditional_expression
%type <bool_val> conditional_term
%type <bool_val> conditional_factor
%type <bool_val> conditional_primary
%type <bool_val> comparison_condition
%type <bool_val> simple_condition
%type <scalar_val> row_constructor
%type <scalar_val> row_name
%type <scalar_val> order_by_item
%type <scalar_val> order_by_item_commalist
%type <scalar_val> opt_limit
%type <scalar_val> create_row
%type <scalar_val> create_row_commalist
%type <scalar_val> row_list_name
%type <scalar_val> row_value
%type <scalar_val> insert_row_value
%type <scalar_val> scalar_expression
%type <scalar_val> update_item_commalist
%type <scalar_val> insert_item_commalist
%type <scalar_val> insert_value_commalist
%type <val> table
%type <val> table_reference
%type <val> table_reference_commalist
%type <column> select_item
%type <column> select_item_commalist
%type <ident_val> key_row_commalist

%pure_parser

%%

sql_expression:
  select_expression
  | insert_expression
  | update_expression
  | delete_expression
  | create_expression
  | drop_expression
;

drop_expression:
  DROP TABLE table
    { ((sql_stmt_t*) stmt)->command = SQL_STATEMENT_COMMAND_DROP;
      ((sql_stmt_t*) stmt)->hasResult = 0;
    }
;

create_expression:
  CREATE TABLE table '(' create_row_commalist opt_key ')'
    { ((sql_stmt_t*) stmt)->command = SQL_STATEMENT_COMMAND_CREATE;
      ((sql_stmt_t*) stmt)->hasResult = 0;
    }
;

create_row_commalist:
  create_row
  | create_row_commalist ',' create_row { $$ = $3 }
;

create_row:
  row_list_name INTEGER opt_not_null
  | row_list_name CHAR '(' INTEGERVAL ')'  opt_not_null
  | row_list_name VARCHAR '(' INTEGERVAL ')'  opt_not_null
  | row_list_name REAL  opt_not_null
      { YFEATURE(create, type_real); }
  | row_list_name BLOB opt_not_null
      { YFEATURE(create, type_blob); }
  | row_list_name TEXT opt_not_null
      { YFEATURE(create, type_text); }
;

opt_not_null:
  /* NULL */
  | NOT NULLVAL
;

opt_key:
  /* NULL */
  | PRIMARY KEY IDENT '(' key_row_commalist ')'
  | PRIMARY KEY '(' key_row_commalist ')'
;

key_row_commalist:
  IDENT
  | key_row_commalist ',' IDENT { $$ = $3 }
;

select_expression:
  SELECT opt_dist select_item_commalist FROM table_reference_commalist
    opt_where opt_group opt_having opt_order_by opt_limit
    { ((sql_stmt_t*) stmt)->command = SQL_STATEMENT_COMMAND_SELECT;
      ((sql_stmt_t*) stmt)->hasResult = 1;
    }
;

opt_order_by:
  /* NULL */
  | ORDER BY order_by_item_commalist
;

order_by_item_commalist:
  order_by_item
  | order_by_item_commalist ',' order_by_item
;

order_by_item:
  row_name
    { sql_order_t o; o.desc = 0; o.col = $1;
      if (($$ = _AllocOrderRow(stmt, &o))  ==  -1) { YYABORT; }
    }
  | row_name ASC
    { sql_order_t o; o.desc = 0; o.col = $1;
      if (($$ = _AllocOrderRow(stmt, &o))  ==  -1) { YYABORT; }
    }
  | row_name DESC
    { sql_order_t o; o.desc = 1; o.col = $1;
      if (($$ = _AllocOrderRow(stmt, &o))  ==  -1) { YYABORT; }
    }
;

opt_limit:
  /* NULL */
    { ((sql_stmt_t*) stmt)->limit_offset = -1;
      ((sql_stmt_t*) stmt)->limit_max = -1;
    }
  | LIMIT INTEGERVAL 
    { if ($2 < 0) {
        ((sql_stmt_t*) stmt)->errMsg = SQL_STATEMENT_ERROR_LIMIT;
      }
      ((sql_stmt_t*) stmt)->limit_offset = 0;
      ((sql_stmt_t*) stmt)->limit_max = $2;
    }
  | LIMIT INTEGERVAL ',' INTEGERVAL
    { if ($2 < 0  ||  $4 < 0) {
        ((sql_stmt_t*) stmt)->errMsg = SQL_STATEMENT_ERROR_LIMIT;
      }
      ((sql_stmt_t*) stmt)->limit_offset = $2;
      ((sql_stmt_t*) stmt)->limit_max = $4;
    }
;

insert_expression:
  INSERT INTO table insert_item_expression VALUES
    '(' insert_value_commalist ')'
    { ((sql_stmt_t*) stmt)->command = SQL_STATEMENT_COMMAND_INSERT;
      ((sql_stmt_t*) stmt)->hasResult = 0;
    }
;

update_expression:
  UPDATE table SET update_item_commalist opt_where
    { ((sql_stmt_t*) stmt)->command = SQL_STATEMENT_COMMAND_UPDATE;
      ((sql_stmt_t*) stmt)->hasResult = 0;
    }
;

delete_expression:
  DELETE FROM table opt_where
    { ((sql_stmt_t*) stmt)->command = SQL_STATEMENT_COMMAND_DELETE;
      ((sql_stmt_t*) stmt)->hasResult = 0;
    }
;

update_item_commalist:
  row_name OPERATOR row_value
    { sql_rowval_list_t rowVal;
      sql_column_list_t column;
      if ($2 != SQL_STATEMENT_OPERATOR_EQ) { YYABORT; }
      column.column = $1;
      if (($$ = _AllocColumnList(stmt, &column)) == -1) { YYABORT; }
      rowVal.val = $3;
      if (_AllocRowValList(stmt, &rowVal) == -1) { YYABORT; }
    }
  | update_item_commalist ',' row_name OPERATOR row_value
    { sql_rowval_list_t rowVal;
      sql_column_list_t column;
      if ($4 != SQL_STATEMENT_OPERATOR_EQ) { YYABORT; }
      column.column = $3;
      if (($$ = _AllocColumnList(stmt, &column)) == -1) { YYABORT; }
      rowVal.val = $5;
      if (_AllocRowValList(stmt, &rowVal) == -1) { YYABORT; }
    }
;

insert_item_expression:
  /* NULL */
  | '(' insert_item_commalist ')'
;

insert_item_commalist:
  row_list_name
  | insert_item_commalist ',' row_list_name { $$ = $3 }
;

insert_value_commalist:
  insert_row_value
  | insert_value_commalist ','  insert_row_value { $$ = $3 }
;

insert_row_value:
  row_value
    { sql_rowval_list_t rowVal;
      rowVal.val = $1;
      if (($$ = _AllocRowValList(stmt, &rowVal)) == -1) {
	  YYABORT;
      }
    }
;

opt_dist:
  /* NULL */ { ((sql_stmt_t*) stmt)->distinct = 0; }
  | ALL      { ((sql_stmt_t*) stmt)->distinct = 0; }
  | DISTINCT { ((sql_stmt_t*) stmt)->distinct = 1; }
;

select_item_commalist:
  select_item
  | select_item_commalist ',' select_item
;

select_item:
  scalar_expression opt_column
    { sql_column_list_t column;
      column.column = $1;
      if (($$ = _AllocColumnList(stmt, &column)) == -1) {
	  YYABORT;
      }
    }
  | opt_range '*'
    { sql_column_t col;
      sql_column_list_t column;

      col.table.ptr = NULL;
      col.column.ptr = NULL;
      if ((column.column = _AllocColumn(stmt, &col)) == -1) {
	  YYABORT;
      }
      if (($$ = _AllocColumnList(stmt, &column)) == -1) {
	  YYABORT;
      }
    }
;

scalar_expression:
/*  Not yet really implemented
*/
  row_constructor
;

opt_column:
  /* NULL */
/* \*  Not yet implemented */
/*   | opt_as column */
/* *\ */
;

table_reference_commalist:
  table_reference
  | table_reference_commalist ',' table_reference
      { YFEATURE(select, join); }
;

table_reference:
  table opt_range_as
/* \*  Not yet implemented */
/*   | '(' table_expression ')' opt_range_as */
/*   | join_table_expression */
/* *\ */
;

table:
  IDENT { sql_table_t table;
          sql_table_list_t tl;
	  table.table = $1;
	  if ((tl.table = _AllocTable(stmt, &table)) == -1) {
	      YYABORT;
	  }
	  if (($$ = _AllocTableList(stmt, &tl)) == -1) {
	      YYABORT;
	  }
	}
;

opt_where:
  /* NULL */                     { ((sql_stmt_t*) stmt)->where = -1; }
  | WHERE conditional_expression { ((sql_stmt_t*) stmt)->where = $2; }
;

opt_range_as:
  /* NULL */
/* \*  Not yet implemented */
/*   | opt_as range_variable '(' column_commalist ')' */
/* *\ */
;

/* opt_as: */
/*   \* NULL *\* */
/* \*  Not yet implemented */
/*  | column */
/*  | AS column */
/* \* */
/* ; */

opt_range:
  /* NULL */
/* \*  Not yet implemented */
/*   | range_variable '.' */
/* *\ */
;

opt_group:
  /* NULL */
/* \*  Not yet implemented */
/* | GROUP BY column_commalist */
/* \* */
;

opt_having:
  /* NULL */
/* \*  Not yet implemented */
/* | HAVING conditional_expression */
/* \* */
;

conditional_expression:
  conditional_term
  | conditional_expression OR conditional_term
    { sql_op_t o;
      o.arg1 = $1;
      o.opNum = SQL_STATEMENT_OPERATOR_OR;
      o.arg2 = $3;
      o.neg = 0;
      if (($$ = _AllocOp(stmt, &o)) == -1) {
	  YYABORT;
      }
#ifdef YYDEBUG
      printf("OR operator: %d OR %d -> %d\n", $1, $3, $$);
#endif
    }
;

conditional_term:
  conditional_factor
  | conditional_term AND conditional_factor
    { sql_op_t o;
      o.arg1 = $1;
      o.opNum = SQL_STATEMENT_OPERATOR_AND;
      o.arg2 = $3;
      o.neg = 0;
      if (($$ = _AllocOp(stmt, &o)) == -1) {
	  YYABORT;
      }
#ifdef YYDEBUG
      printf("AND operator: %d AND %d -> %d\n", $1, $3, $$);
#endif
    }
;

conditional_factor:
  conditional_primary
  | NOT conditional_primary
    { sql_val_t* o = ((sql_val_t*) ((sql_stmt_t*) stmt)->values.data)+$2;
      if (o->type != SQL_STATEMENT_TYPE_OP) {
	  ((sql_stmt_t*) stmt)->errMsg = SQL_STATEMENT_ERROR_INTERNAL;
	  YYABORT;
      }
      o->data.o.neg = !o->data.o.neg;
      $$ = $2;
    }
;

conditional_primary:
  simple_condition
  | '(' conditional_expression ')' { $$ = $2 }
;

simple_condition:
  comparison_condition
/* \*  Not yet implemented */
/*   | in_condition */
/*   | match_condition */
/*   | all_or_any_condition */
/*   | simple_condition */
/* *\ */
;

comparison_condition:
  row_constructor OPERATOR row_constructor
    { sql_op_t o;
      o.arg1 = $1;
      o.opNum = $2;
      o.arg2 = $3;
      o.neg = 0;
      if (($$ = _AllocOp(stmt, &o)) == -1) {
	  YYABORT;
      }
#ifdef YYDEBUG
      printf("comparison_operator: %d %d %d -> %d\n", $1, $2, $3, $$);
#endif
    }
  | row_constructor IS NULLVAL
    { sql_op_t o;
      o.arg1 = $1;
      o.opNum = SQL_STATEMENT_OPERATOR_IS;
      o.arg2 = $3;
      o.neg = 0;
      if (($$ = _AllocOp(stmt, &o)) == -1) {
	  YYABORT;
      }
#ifdef YYDEBUG
      printf("IS operator: %d AND %d -> %d\n", $1, $3, $$);
#endif
    }
  | row_constructor IS NOT NULLVAL
    { sql_op_t o;
      o.arg1 = $1;
      o.opNum = SQL_STATEMENT_OPERATOR_IS;
      o.arg2 = $4;
      o.neg = 1;
      if (($$ = _AllocOp(stmt, &o)) == -1) {
	  YYABORT;
      }
#ifdef YYDEBUG
      printf("IS NOT operator: %d AND %d -> %d\n", $1, $4, $$);
#endif
    }
;

/* \*  Not yet implemented */

/* in_condition: */
/*   row_constructor opt_not IN '(' table_expression ')' */
/*   | scalar_expression opt_not IN scalar_expression_commalist */
/* ; */

/* opt_not: \* NULL *\ | NOT ; */

/* match_condition: */
/*   row_constructor MATCH UNIQUE '(' table_expression ')' */
/* ; */

/* all_or_any_condition: */
/*   row_constructor OPERATOR ALL '(' table_expression ')' */
/*   | row_constructor OPERATOR ANY '(' table_expression ')' */
/* ; */

/* exists_condition: EXISTS '(' table_expression ')' */
/* ; */

/* *\ */

row_constructor:
  row_value
  | row_name 
;

row_value:
  INTEGERVAL { if (($$ = _AllocInteger(stmt, $1)) == -1) { YYABORT; } }
  | REALVAL  { if (($$ = _AllocReal(stmt, $1)) == -1) { YYABORT; } }
  | STRING   { if (($$ = _AllocString(stmt, &$1)) == -1) { YYABORT; } }
  | NULLVAL  { $$ = $1; }
  | PARAM    { if (($$ = _AllocParam(stmt, &$1)) == -1) { YYABORT; } }
;

row_name:
  IDENT
    { sql_column_t col;
      sql_table_list_t* tl;
      sql_val_t* val;
      if (((sql_stmt_t*) stmt)->tables.currentNum == 0) {
	  col.table.ptr = NULL;
      } else {
	  tl = ((sql_stmt_t*)stmt)->tables.data;
	  val = ((sql_val_t*) ((sql_stmt_t*)stmt)->values.data) + tl->table;
	  col.table = val->data.tbl.table;
      }
      col.column = $1;
      if (($$ = _AllocColumn(stmt, &col)) == -1) { YYABORT; }
    }
/* \*  Not yet implemented */
/*   | IDENT '.' IDENT */
;

row_list_name:
  row_name
    { sql_column_list_t column;
      column.column = $1;
      if (($$ = _AllocColumnList(stmt, &column)) == -1) {
	  YYABORT;
      }
    }
;
%%


static int ryylex(YYSTYPE* lvalp, void* s);
int yylex (YYSTYPE* lvalp, void* s) {
    int token = ryylex(lvalp, s);
#ifdef YYDEBUG
    printf("yylex: token %d\n", token);
#endif
    switch (token) {
      case NULLVAL:
	lvalp->null_val = _AllocNull(s);
	break;
    }
    return token;
}

static int ryylex(YYSTYPE* lvalp, void* s) {
    sql_stmt_t* stmt = s;

    char* queryPtr = stmt->queryPtr;
    char* queryEnd = stmt->query + stmt->queryLen;

    while (queryEnd > queryPtr  &&  isspace(*queryPtr)) {
        ++queryPtr;
    }
    stmt->queryPtr = stmt->errPtr = queryPtr;
    if (queryPtr == queryEnd) {
        return EOF;
    }

    if (*queryPtr == '-'  ||  *queryPtr == '.'  ||
	(*queryPtr >= '0'  &&  *queryPtr <= '9')) {
	/*
 	 *  Looks like a number
	 */
        int minus = 0;

	while (*queryPtr == '-') {
	    minus = !minus;
	    if (++queryPtr == queryEnd) {
	        stmt->errMsg = SQL_STATEMENT_ERROR_PARSE;
		return ERROR;
	    }
	}
	while (isspace(*queryPtr)) {
	    if (++queryPtr == queryEnd) {
	        stmt->errMsg = SQL_STATEMENT_ERROR_PARSE;
		return ERROR;
	    }
	}
	if (*queryPtr != '.'  &&  (*queryPtr < '0'  ||  *queryPtr > '9')) {
	    stmt->errMsg = SQL_STATEMENT_ERROR_PARSE;
	    return ERROR;
	}

	while (*queryPtr >= '0'  &&  *queryPtr <= '9') {
	    if (++queryPtr == queryEnd) {
	        break;
	    }
	}
	if (queryPtr == queryEnd  ||
	    (*queryPtr != '.'  &&  *queryPtr != 'E'  &&  *queryPtr != 'e')) {
 	    /*
 	     *  An integer
	     */
	    int n;
	    if (sscanf(stmt->queryPtr, " %d%n", &lvalp->int_val, &n) != 1) {
	        stmt->errMsg = SQL_STATEMENT_ERROR_PARSE;
		return ERROR;
	    }
	    stmt->queryPtr += n;
	    if (stmt->queryPtr > queryEnd) {
 	        /* 
 		 *  Should not happen ...
		 */
	        queryPtr = queryEnd;
	    }
	    return INTEGERVAL;
	} else {
 	    /*
 	     *  A real value
	     */
	   int n;
	   if (sscanf(stmt->queryPtr, " %lf%n", &lvalp->real_val, &n) != 1) {
	        stmt->errMsg = SQL_STATEMENT_ERROR_PARSE;
		return ERROR;
	    }
	    stmt->queryPtr += n;
	    if (stmt->queryPtr > queryEnd) {
 	        /*
 		 *  Should not happen ...
		 */
	        queryPtr = queryEnd;
	    }
	    return REALVAL;
	}
    }

    if (*queryPtr == '\''  ||  *queryPtr == '"') {
        /*
 	 *  This is a string
	 */
        char quoteChar = *queryPtr++;
	char c;
	int stringLen = 0;
	while (queryPtr < queryEnd) {
	    c = *queryPtr++;
	    if (c == '\\') {
	        if (queryPtr == queryEnd) {
		    break;
		}
		queryPtr++;
	    } else if (c == quoteChar) {
	        lvalp->string_val.ePtr = stmt->queryPtr;
		lvalp->string_val.pPtr = NULL;
		lvalp->string_val.eLen = queryPtr - stmt->queryPtr;
		lvalp->string_val.pLen = stringLen;
		stmt->queryPtr = queryPtr;
		return STRING;
	    }
	    ++stringLen;
	}
	stmt->errMsg = SQL_STATEMENT_ERROR_PARSE;
	return ERROR;
    }


    if (*queryPtr == '=') {
        ++queryPtr;
	if (queryPtr < queryEnd) {
	    if (*queryPtr == '=') {
	        ++queryPtr;
	    }
	}
	lvalp->operator = SQL_STATEMENT_OPERATOR_EQ;
	stmt->queryPtr = queryPtr;
	return OPERATOR;
    }
    if (*queryPtr == '>') {
        ++queryPtr;
	if (queryPtr < queryEnd  &&  *queryPtr == '=') {
	    ++queryPtr;
	    lvalp->operator = SQL_STATEMENT_OPERATOR_GE;
	    stmt->queryPtr = queryPtr;
	    return OPERATOR;
	}
	lvalp->operator = SQL_STATEMENT_OPERATOR_GT;
	stmt->queryPtr = queryPtr;
	return OPERATOR;
    }
    if (*queryPtr == '<') {
        ++queryPtr;
	if (queryPtr < queryEnd  &&  *queryPtr == '=') {
	    ++queryPtr;
	    lvalp->operator = SQL_STATEMENT_OPERATOR_LE;
	    stmt->queryPtr = queryPtr;
	    return OPERATOR;
	}
	if (queryPtr < queryEnd  &&  *queryPtr == '>') {
	    ++queryPtr;
	    lvalp->operator = SQL_STATEMENT_OPERATOR_NE;
	    stmt->queryPtr = queryPtr;
	    return OPERATOR;
	}
	lvalp->operator = SQL_STATEMENT_OPERATOR_LT;
	stmt->queryPtr = queryPtr;
	return OPERATOR;
    }
    if (*queryPtr == '!') {
        ++queryPtr;
        if (queryPtr < queryEnd  &&  *queryPtr == '=') {
	    ++queryPtr;
	    lvalp->operator = SQL_STATEMENT_OPERATOR_NE;
	    stmt->queryPtr = queryPtr;
	    return OPERATOR;
	}
	return NOT;
    }

    if (*queryPtr == '?') {
        stmt->queryPtr = ++queryPtr;
	lvalp->param.num = stmt->numParam++;
	return PARAM;
    }

    if (isalpha(*queryPtr)) {
        switch (queryPtr[0]) {
	  case 'a':
	  case 'A':
	    if (queryPtr+3 <= queryEnd  &&
		(queryPtr[1] == 'l'  ||  queryPtr[1] == 'L')  &&
		(queryPtr[2] == 'l'  ||  queryPtr[2] == 'L')  &&
		(queryPtr+3 == queryEnd  || !isalnum_(queryPtr[3]))) {
	        stmt->queryPtr = queryPtr + 3;
		return ALL;
	    }
	    if (queryPtr+3 <= queryEnd  &&
		(queryPtr[1] == 'n'  ||  queryPtr[1] == 'N')  &&
		(queryPtr[2] == 'd'  ||  queryPtr[2] == 'D')  &&
		(queryPtr+3 == queryEnd  || !isalnum_(queryPtr[3]))) {
	        stmt->queryPtr = queryPtr + 3;
		return AND;
	    }
	    if (queryPtr+3 <= queryEnd  &&
		(queryPtr[1] == 's'  ||  queryPtr[1] == 'S')  &&
		(queryPtr[2] == 'c'  ||  queryPtr[2] == 'C')  &&
		(queryPtr+3 == queryEnd  || !isalnum_(queryPtr[3]))) {
	        stmt->queryPtr = queryPtr + 3;
		return ASC;
	    }
	    break;
	  case 'b':
	  case 'B':
	    if (queryPtr+2 <= queryEnd  &&
		(queryPtr[1] == 'y'  ||  queryPtr[1] == 'Y')  &&
		(queryPtr+2 == queryEnd  || !isalnum_(queryPtr[2]))) {
	        stmt->queryPtr = queryPtr + 2;
		return BY;
	    }
	    if (FEATURE(create, type_blob)  &&
		queryPtr+4 <= queryEnd  &&
		(queryPtr[1] == 'l'  ||  queryPtr[1] == 'L')  &&
		(queryPtr[2] == 'o'  ||  queryPtr[2] == 'O')  &&
		(queryPtr[3] == 'b'  ||  queryPtr[3] == 'B')  &&
		(queryPtr+4 == queryEnd  || !isalnum_(queryPtr[4]))) {
	        stmt->queryPtr = queryPtr + 4;
		return BLOB;
	    }
	    break;
	  case 'c':
	  case 'C':
	    if (queryPtr+6 <= queryEnd  &&
		(queryPtr[1] == 'r'  ||  queryPtr[1] == 'R')  &&
		(queryPtr[2] == 'e'  ||  queryPtr[2] == 'E')  &&
		(queryPtr[3] == 'a'  ||  queryPtr[3] == 'A')  &&
		(queryPtr[4] == 't'  ||  queryPtr[4] == 'T')  &&
		(queryPtr[5] == 'e'  ||  queryPtr[5] == 'E')  &&
		(queryPtr+6 == queryEnd  || !isalnum_(queryPtr[6]))) {
	        stmt->queryPtr = queryPtr + 6;
		return CREATE;
	    }
	    if (queryPtr+4 <= queryEnd  &&
		(queryPtr[1] == 'h'  ||  queryPtr[1] == 'H')  &&
		(queryPtr[2] == 'a'  ||  queryPtr[2] == 'A')  &&
		(queryPtr[3] == 'r'  ||  queryPtr[3] == 'R')  &&
		(queryPtr+4 == queryEnd  || !isalnum_(queryPtr[4]))) {
	        stmt->queryPtr = queryPtr + 4;
		return CHAR;
	    }
	    if (FEATURE(select, clike)  &&  queryPtr+5 <= queryEnd  &&
		(queryPtr[1] == 'l'  ||  queryPtr[1] == 'L')  &&
		(queryPtr[2] == 'i'  ||  queryPtr[2] == 'I')  &&
		(queryPtr[3] == 'k'  ||  queryPtr[3] == 'K')  &&
		(queryPtr[4] == 'e'  ||  queryPtr[4] == 'E')  &&
		(queryPtr+5 == queryEnd  || !isalnum_(queryPtr[5]))) {
	        stmt->queryPtr = queryPtr + 5;
		lvalp->operator = SQL_STATEMENT_OPERATOR_CLIKE;
		return OPERATOR;
	    }
	    break;
	  case 'd':
	  case 'D':
	    if (queryPtr+4 <= queryEnd  &&
		(queryPtr[1] == 'e'  ||  queryPtr[1] == 'E')  &&
		(queryPtr[2] == 's'  ||  queryPtr[2] == 'S')  &&
		(queryPtr[3] == 'c'  ||  queryPtr[3] == 'C')  &&
		(queryPtr+4 == queryEnd  || !isalnum_(queryPtr[4]))) {
	        stmt->queryPtr = queryPtr + 4;
		return DESC;
	    }
	    if (queryPtr+4 <= queryEnd  &&
		(queryPtr[1] == 'r'  ||  queryPtr[1] == 'R')  &&
		(queryPtr[2] == 'o'  ||  queryPtr[2] == 'O')  &&
		(queryPtr[3] == 'p'  ||  queryPtr[3] == 'P')  &&
		(queryPtr+4 == queryEnd  || !isalnum_(queryPtr[4]))) {
	        stmt->queryPtr = queryPtr + 4;
		return DROP;
	    }
	    if (queryPtr+6 <= queryEnd  &&
		(queryPtr[1] == 'e'  ||  queryPtr[1] == 'E')  &&
		(queryPtr[2] == 'l'  ||  queryPtr[2] == 'L')  &&
		(queryPtr[3] == 'e'  ||  queryPtr[3] == 'E')  &&
		(queryPtr[4] == 't'  ||  queryPtr[4] == 'T')  &&
		(queryPtr[5] == 'e'  ||  queryPtr[5] == 'E')  &&
		(queryPtr+6 == queryEnd  || !isalnum_(queryPtr[6]))) {
	        stmt->queryPtr = queryPtr + 6;
		return DELETE;
	    }
	    if (queryPtr+8 <= queryEnd  &&
		(queryPtr[1] == 'i'  ||  queryPtr[1] == 'I')  &&
		(queryPtr[2] == 's'  ||  queryPtr[2] == 'S')  &&
		(queryPtr[3] == 't'  ||  queryPtr[3] == 'T')  &&
		(queryPtr[4] == 'i'  ||  queryPtr[4] == 'I')  &&
		(queryPtr[5] == 'n'  ||  queryPtr[5] == 'N')  &&
		(queryPtr[6] == 'c'  ||  queryPtr[6] == 'C')  &&
		(queryPtr[7] == 't'  ||  queryPtr[7] == 'T')  &&
		(queryPtr+8 == queryEnd  || !isalnum_(queryPtr[8]))) {
	        stmt->queryPtr = queryPtr + 8;
		return DISTINCT;
	    }
	    break;
	  case 'f':
	  case 'F':
	    if (queryPtr+4 <= queryEnd  &&
		(queryPtr[1] == 'r'  ||  queryPtr[1] == 'R')  &&
		(queryPtr[2] == 'o'  ||  queryPtr[2] == 'O')  &&
		(queryPtr[3] == 'm'  ||  queryPtr[3] == 'M')  &&
		(queryPtr+4 == queryEnd  || !isalnum_(queryPtr[4]))) {
	        stmt->queryPtr = queryPtr + 4;
		return FROM;
	    }
	    break;
	  case 'i':
	  case 'I':
	    if (queryPtr+2 <= queryEnd  &&
		(queryPtr[1] == 's'  ||  queryPtr[1] == 'S')  &&
		(queryPtr+2 == queryEnd  || !isalnum_(queryPtr[2]))) {
	        stmt->queryPtr = queryPtr + 2;
		return IS;
	    }
	    if (queryPtr+4 <= queryEnd  &&
		(queryPtr[1] == 'n'  ||  queryPtr[1] == 'N')  &&
		(queryPtr[2] == 't'  ||  queryPtr[2] == 'T')  &&
		(queryPtr[3] == 'o'  ||  queryPtr[3] == 'O')  &&
		(queryPtr+4 == queryEnd  || !isalnum_(queryPtr[4]))) {
	        stmt->queryPtr = queryPtr + 4;
		return INTO;
	    }
	    if (queryPtr+6 <= queryEnd  &&
		(queryPtr[1] == 'n'  ||  queryPtr[1] == 'N')  &&
		(queryPtr[2] == 's'  ||  queryPtr[2] == 'S')  &&
		(queryPtr[3] == 'e'  ||  queryPtr[3] == 'E')  &&
		(queryPtr[4] == 'r'  ||  queryPtr[4] == 'R')  &&
		(queryPtr[5] == 't'  ||  queryPtr[5] == 'T')  &&
		(queryPtr+6 == queryEnd  || !isalnum_(queryPtr[6]))) {
	        stmt->queryPtr = queryPtr + 6;
		return INSERT;
	    }
	    if (queryPtr+3 <= queryEnd  &&
		(queryPtr[1] == 'n'  ||  queryPtr[1] == 'N')  &&
		(queryPtr[2] == 't'  ||  queryPtr[2] == 'T')  &&
		(queryPtr+3 == queryEnd  || !isalnum_(queryPtr[3]))) {
	        stmt->queryPtr = queryPtr + 3;
		return INTEGER;
	    }
	    if (queryPtr+7 <= queryEnd  &&
		(queryPtr[1] == 'n'  ||  queryPtr[1] == 'N')  &&
		(queryPtr[2] == 't'  ||  queryPtr[2] == 'T')  &&
		(queryPtr[3] == 'e'  ||  queryPtr[3] == 'E')  &&
		(queryPtr[4] == 'g'  ||  queryPtr[4] == 'G')  &&
		(queryPtr[5] == 'e'  ||  queryPtr[5] == 'E')  &&
		(queryPtr[6] == 'r'  ||  queryPtr[6] == 'R')  &&
		(queryPtr+7 == queryEnd  || !isalnum_(queryPtr[7]))) {
	        stmt->queryPtr = queryPtr + 7;
		return INTEGER;
	    }
	    break;
	  case 'k':
	  case 'K':
	    if (queryPtr+3 <= queryEnd  &&
		(queryPtr[1] == 'e'  ||  queryPtr[1] == 'E')  &&
		(queryPtr[2] == 'y'  ||  queryPtr[2] == 'Y')  &&
		(queryPtr+3 == queryEnd  || !isalnum_(queryPtr[3]))) {
	        stmt->queryPtr = queryPtr + 3;
		return KEY;
	    }
	    break;
	  case 'l':
	  case 'L':
	    if (queryPtr+4 <= queryEnd  &&
		(queryPtr[1] == 'i'  ||  queryPtr[1] == 'I')  &&
		(queryPtr[2] == 'k'  ||  queryPtr[2] == 'K')  &&
		(queryPtr[3] == 'e'  ||  queryPtr[3] == 'E')  &&
		(queryPtr+4 == queryEnd  || !isalnum_(queryPtr[4]))) {
	        stmt->queryPtr = queryPtr + 4;
		lvalp->operator = SQL_STATEMENT_OPERATOR_LIKE;
		return OPERATOR;
	    }
	    if (queryPtr+5 <= queryEnd  &&
		(queryPtr[1] == 'i'  ||  queryPtr[1] == 'I')  &&
		(queryPtr[2] == 'm'  ||  queryPtr[2] == 'M')  &&
		(queryPtr[3] == 'i'  ||  queryPtr[3] == 'I')  &&
		(queryPtr[4] == 't'  ||  queryPtr[4] == 'T')  &&
		(queryPtr+5 == queryEnd  || !isalnum_(queryPtr[5]))) {

	        stmt->queryPtr = queryPtr + 5;
		return LIMIT;
	    }
	    break;
	  case 'n':
	  case 'N':
	    if (queryPtr+3 <= queryEnd  &&
		(queryPtr[1] == 'o'  ||  queryPtr[1] == 'O')  &&
		(queryPtr[2] == 't'  ||  queryPtr[2] == 'T')  &&
		(queryPtr+3 == queryEnd  || !isalnum_(queryPtr[3]))) {
	        stmt->queryPtr = queryPtr + 3;
		return NOT;
	    }
	    if (queryPtr+4 <= queryEnd  &&
		(queryPtr[1] == 'u'  ||  queryPtr[1] == 'U')  &&
		(queryPtr[2] == 'l'  ||  queryPtr[2] == 'L')  &&
		(queryPtr[3] == 'l'  ||  queryPtr[3] == 'L')  &&
		(queryPtr+4 == queryEnd  || !isalnum_(queryPtr[4]))) {
	        stmt->queryPtr = queryPtr + 4;
		return NULLVAL;
	    }
	    break;
	  case 'o':
	  case 'O':
	    if (queryPtr+2 <= queryEnd  &&
		(queryPtr[1] == 'r'  ||  queryPtr[1] == 'R')  &&
		(queryPtr+2 == queryEnd  || !isalnum_(queryPtr[2]))) {
	        stmt->queryPtr = queryPtr + 2;
		return OR;
	    }
	    if (queryPtr+5 <= queryEnd  &&
		(queryPtr[1] == 'r'  ||  queryPtr[1] == 'R')  &&
		(queryPtr[2] == 'd'  ||  queryPtr[2] == 'D')  &&
		(queryPtr[3] == 'e'  ||  queryPtr[3] == 'E')  &&
		(queryPtr[4] == 'r'  ||  queryPtr[4] == 'R')  &&
		(queryPtr+5 == queryEnd  || !isalnum_(queryPtr[5]))) {
	        stmt->queryPtr = queryPtr + 5;
		return ORDER;
	    }
	    break;
	  case 'p':
	  case 'P':
	    if (queryPtr+7 <= queryEnd  &&
		(queryPtr[1] == 'r'  ||  queryPtr[1] == 'R')  &&
		(queryPtr[2] == 'i'  ||  queryPtr[2] == 'I')  &&
		(queryPtr[3] == 'm'  ||  queryPtr[3] == 'M')  &&
		(queryPtr[4] == 'a'  ||  queryPtr[4] == 'A')  &&
		(queryPtr[5] == 'r'  ||  queryPtr[5] == 'R')  &&
		(queryPtr[6] == 'y'  ||  queryPtr[6] == 'Y')  &&
		(queryPtr+7 == queryEnd  || !isalnum_(queryPtr[7]))) {
	        stmt->queryPtr = queryPtr + 7;
		return PRIMARY;
	    }
	    break;
	  case 'r':
	  case 'R':
	    if (FEATURE(create, type_real)  &&
		queryPtr+4 <= queryEnd  &&
		(queryPtr[1] == 'e'  ||  queryPtr[1] == 'E')  &&
		(queryPtr[2] == 'a'  ||  queryPtr[2] == 'A')  &&
		(queryPtr[3] == 'l'  ||  queryPtr[3] == 'L')  &&
		(queryPtr+4 == queryEnd  || !isalnum_(queryPtr[4]))) {
	        stmt->queryPtr = queryPtr + 4;
		return REAL;
	    }
	    break;
	  case 's':
	  case 'S':
	    if (queryPtr+3 <= queryEnd  &&
		(queryPtr[1] == 'e'  ||  queryPtr[1] == 'E')  &&
		(queryPtr[2] == 't'  ||  queryPtr[2] == 'T')  &&
		(queryPtr+3 == queryEnd  || !isalnum_(queryPtr[3]))) {
	        stmt->queryPtr = queryPtr + 3;
		return SET;
	    }
	    if (queryPtr+6 <= queryEnd  &&
		(queryPtr[1] == 'e'  ||  queryPtr[1] == 'E')  &&
		(queryPtr[2] == 'l'  ||  queryPtr[2] == 'L')  &&
		(queryPtr[3] == 'e'  ||  queryPtr[3] == 'E')  &&
		(queryPtr[4] == 'c'  ||  queryPtr[4] == 'C')  &&
		(queryPtr[5] == 't'  ||  queryPtr[5] == 'T')  &&
		(queryPtr+6 == queryEnd  || !isalnum_(queryPtr[6]))) {
	        stmt->queryPtr = queryPtr + 6;
		return SELECT;
	    }
	    break;
	  case 't':
	  case 'T':
	    if (queryPtr+5 <= queryEnd  &&
		(queryPtr[1] == 'a'  ||  queryPtr[1] == 'A')  &&
		(queryPtr[2] == 'b'  ||  queryPtr[2] == 'B')  &&
		(queryPtr[3] == 'l'  ||  queryPtr[3] == 'L')  &&
		(queryPtr[4] == 'e'  ||  queryPtr[4] == 'E')  &&
		(queryPtr+5 == queryEnd  || !isalnum_(queryPtr[5]))) {
	        stmt->queryPtr = queryPtr + 5;
		return TABLE;
	    }
	    if (FEATURE(create, type_text)  &&
		queryPtr+4 <= queryEnd  &&
		(queryPtr[1] == 'e'  ||  queryPtr[1] == 'E')  &&
		(queryPtr[2] == 'x'  ||  queryPtr[2] == 'X')  &&
		(queryPtr[3] == 't'  ||  queryPtr[3] == 'T')  &&
		(queryPtr+4 == queryEnd  || !isalnum_(queryPtr[4]))) {
	        stmt->queryPtr = queryPtr + 4;
		return TEXT;
	    }
	    break;
	  case 'u':
	  case 'U':
	    if (queryPtr+6 <= queryEnd  &&
		(queryPtr[1] == 'p'  ||  queryPtr[1] == 'P')  &&
		(queryPtr[2] == 'd'  ||  queryPtr[2] == 'D')  &&
		(queryPtr[3] == 'a'  ||  queryPtr[3] == 'A')  &&
		(queryPtr[4] == 't'  ||  queryPtr[4] == 'T')  &&
		(queryPtr[5] == 'e'  ||  queryPtr[5] == 'E')  &&
		(queryPtr+6 == queryEnd  || !isalnum_(queryPtr[6]))) {
	        stmt->queryPtr = queryPtr + 6;
		return UPDATE;
	    }
	  case 'v':
	  case 'V':
	    if (queryPtr+6 <= queryEnd  &&
		(queryPtr[1] == 'a'  ||  queryPtr[1] == 'A')  &&
		(queryPtr[2] == 'l'  ||  queryPtr[2] == 'L')  &&
		(queryPtr[3] == 'u'  ||  queryPtr[3] == 'U')  &&
		(queryPtr[4] == 'e'  ||  queryPtr[4] == 'E')  &&
		(queryPtr[5] == 's'  ||  queryPtr[5] == 'S')  &&
		(queryPtr+6 == queryEnd  || !isalnum_(queryPtr[6]))) {
	        stmt->queryPtr = queryPtr + 6;
		return VALUES;
	    }
	    if (queryPtr+7 <= queryEnd  &&
		(queryPtr[1] == 'a'  ||  queryPtr[1] == 'A')  &&
		(queryPtr[2] == 'r'  ||  queryPtr[2] == 'R')  &&
		(queryPtr[3] == 'c'  ||  queryPtr[3] == 'C')  &&
		(queryPtr[4] == 'h'  ||  queryPtr[4] == 'H')  &&
		(queryPtr[5] == 'a'  ||  queryPtr[5] == 'A')  &&
		(queryPtr[6] == 'r'  ||  queryPtr[6] == 'R')  &&
		(queryPtr+7 == queryEnd  || !isalnum_(queryPtr[7]))) {
	        stmt->queryPtr = queryPtr + 7;
		return VARCHAR;
	    }
	    break;
	  case 'w':
	  case 'W':
	    if (queryPtr+5 <= queryEnd  &&
		(queryPtr[1] == 'h'  ||  queryPtr[1] == 'H')  &&
		(queryPtr[2] == 'e'  ||  queryPtr[2] == 'E')  &&
		(queryPtr[3] == 'r'  ||  queryPtr[3] == 'R')  &&
		(queryPtr[4] == 'e'  ||  queryPtr[4] == 'E')  &&
		(queryPtr+5 == queryEnd  || !isalnum_(queryPtr[5]))) {

	        stmt->queryPtr = queryPtr + 5;
		return WHERE;
	    }
	    break;
	}

	while (queryPtr < queryEnd  &&  isalnum_(*queryPtr)) {
	  ++queryPtr;
	}
	lvalp->ident_val.ptr = stmt->queryPtr;
	lvalp->ident_val.len = queryPtr - stmt->queryPtr;
	stmt->queryPtr = queryPtr;
	return IDENT;
    }

    return *stmt->queryPtr++;
}



/*
 *  These functions are called from yyparse().
 */

static int _AllocData(sql_stmt_t* stmt, sql_array_t* array) {
    int nextNum = array->currentNum;
    if (nextNum < 0) {
        stmt->errMsg = SQL_STATEMENT_ERROR_OUT_OF_BOUNDS;
	return -1;
    }
    if (nextNum == array->maxNum) {
        void* newArray;
	int maxNum;
	if (array->maxNum) {
	    maxNum = array->maxNum << 1;
	    newArray = realloc(array->data, array->elemSize * maxNum);
	} else {
	    maxNum = 32;
	    newArray = malloc(array->elemSize * maxNum);
	}
	if (!newArray) {
	    stmt->errMsg = SQL_STATEMENT_ERROR_MEM;
	    return -1;
	}
	array->data = newArray;
	array->maxNum = maxNum;
    }
    array->currentNum = nextNum+1;
    return nextNum;
}

static int _AllocString(sql_stmt_t* stmt, sql_string_t* str) {
    int num = _AllocData(stmt, &stmt->values);
    if (num != -1) {
        sql_val_t* val = ((sql_val_t*) stmt->values.data)+num;
	val->data.str = *str;
	val->type = SQL_STATEMENT_TYPE_STRING;
    }
    return num;
}

static int _AllocOp(sql_stmt_t* stmt, sql_op_t* o) {
    int num = _AllocData(stmt, &stmt->values);
    if (num != -1) {
        sql_val_t* val = ((sql_val_t*) stmt->values.data)+num;
	val->data.o = *o;
	val->type = SQL_STATEMENT_TYPE_OP;
    }
    return num;
}

static int _AllocInteger(sql_stmt_t* stmt, int i) {
    int num = _AllocData(stmt, &stmt->values);
    if (num != -1) {
        sql_val_t* val = ((sql_val_t*) stmt->values.data)+num;
	val->data.i = i;
	val->type = SQL_STATEMENT_TYPE_INTEGER;
    }
    return num;
}

static int _AllocReal(sql_stmt_t* stmt, double d) {
    int num = _AllocData(stmt, &stmt->values);
    if (num != -1) {
        sql_val_t* val = ((sql_val_t*) stmt->values.data)+num;
	val->data.d = d;
	val->type = SQL_STATEMENT_TYPE_REAL;
    }
    return num;
}

static int _AllocNull(sql_stmt_t* stmt) {
    return -1;
}

static void _InitArray(sql_array_t* array, int size) {
    array->data = NULL;
    array->currentNum = array->maxNum = 0;
    array->elemSize = size;
}

static void _DestroyArray(sql_array_t* array) {
    if (array->data) {
        free(array->data);
	array->data = NULL;
    }
    array->maxNum = array->currentNum = 0;
}

static int _AllocColumn(sql_stmt_t* stmt, sql_column_t* column) {
    int num = _AllocData(stmt, &stmt->values);
    if (num != -1) {
        sql_val_t* columns = ((sql_val_t*) stmt->values.data)+num;
	columns->data.col = *column;
	columns->type = SQL_STATEMENT_TYPE_COLUMN;
    }
    return num;
}

static int _AllocColumnList(sql_stmt_t* stmt, sql_column_list_t* column) {
    int num = _AllocData(stmt, &stmt->columns);
    if (num != -1) {
        *(((sql_column_list_t*) stmt->columns.data)+num) = *column;
    }
    return num;
}

static int _AllocOrderRow(sql_stmt_t* stmt, sql_order_t* o) {
    int num = _AllocData(stmt, &stmt->orderrows);
    if (num != -1) {
        *(((sql_order_t*) stmt->orderrows.data)+num) = *o;
    }
    return num;
}

static int _AllocParam(sql_stmt_t* stmt, sql_param_t* param) {
    int num = _AllocData(stmt, &stmt->values);
    if (num != -1) {
        sql_val_t* val = ((sql_val_t*) stmt->values.data)+num;
	val->data.p = *param;
	val->type = SQL_STATEMENT_TYPE_PARAM;
    }
    return num;
}

static int _AllocTable(sql_stmt_t* stmt, sql_table_t* table) {
    int num = _AllocData(stmt, &stmt->values);
    if (num != -1) {
        sql_val_t* val = ((sql_val_t*) stmt->values.data)+num;
	val->data.tbl = *table;
	val->type = SQL_STATEMENT_TYPE_TABLE;
    }
    return num;
}

static int _AllocTableList(sql_stmt_t* stmt, sql_table_list_t* table) {
    int num = _AllocData(stmt, &stmt->tables);
    if (num != -1) {
        sql_table_list_t* tables =
	    ((sql_table_list_t*) stmt->tables.data)+num;
	*tables = *table;
    }
    return num;
}

static int _AllocRowValList(sql_stmt_t* stmt, sql_rowval_list_t* rval) {
    int num = _AllocData(stmt, &stmt->rowvals);
    if (num != -1) {
        sql_rowval_list_t* rvals =
	    ((sql_rowval_list_t*) stmt->rowvals.data)+num;
	*rvals = *rval;
    }
    return num;
}

int SQL_Statement_Prepare(sql_stmt_t* stmt, char* query,
		       int queryLen) {
    if (!query) {
        stmt->errMsg = SQL_STATEMENT_ERROR_PARSE;
	stmt->errPtr = "";
	return 0;
    }
    _InitArray(&stmt->values, sizeof(sql_val_t));
    _InitArray(&stmt->columns, sizeof(sql_column_list_t));
    _InitArray(&stmt->tables, sizeof(sql_table_list_t));
    _InitArray(&stmt->rowvals, sizeof(sql_rowval_list_t));
    _InitArray(&stmt->orderrows, sizeof(sql_order_t));
    stmt->numParam = 0;
    stmt->command = -1;
    stmt->query = query;
    stmt->queryLen = queryLen;
    stmt->queryPtr = stmt->errPtr = query;
    stmt->errMsg = 0;
#ifdef YYDEBUG
    yydebug = 1;
#endif

    if (yyparse(stmt)  ||  stmt->errMsg  ||  stmt->command == -1) {
        if (!stmt->errMsg) {
	    stmt->errMsg = SQL_STATEMENT_ERROR_PARSE;
	}
	SQL_Statement_Finish(stmt);
	SQL_Statement_Destroy(stmt);
	return 0;
    }
    return 1;
}

int SQL_Statement_Finish(sql_stmt_t* stmt) {
    return 1;
}

void SQL_Statement_Destroy(sql_stmt_t* stmt) {
    sql_val_t* values = stmt->values.data;
    if (values) {
        int i;
	for (i = 0;  i < stmt->values.currentNum;  i++, values++) {
	    if (values->type == SQL_STATEMENT_TYPE_STRING
		&&  values->data.str.pPtr) {
	        free(values->data.str.pPtr);
		values->data.str.pPtr = NULL;
	    }
	}
    }

    _DestroyArray(&stmt->rowvals);
    _DestroyArray(&stmt->values);
    _DestroyArray(&stmt->columns);
    _DestroyArray(&stmt->tables);
    _DestroyArray(&stmt->orderrows);
}

static int yyerror(const char* msg) {
#ifdef YYDEBUG
    printf("yyerror: Error %s\n", msg);
#endif
    return 1;
}
