/*
 *  DBD::CSV - SQL engine and DBI driver for CSV files
 *
 *  Copyright (c) 1998  Jochen Wiedmann
 *
 *  You may distribute this under the terms of either the GNU General Public
 *  License or the Artistic License, as specified in the Perl README file.
 *
 *  Author:  Jochen Wiedmann
 *           Am Eisteich 9
 *           72555 Metzingen
 *           Germany
 *
 *           Email: joe@ispsoft.de
 *           Fax: +49 7123 / 14892
 */


#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "sql_data.h"


/***************************************************************************
 *
 *  WHERE clause evaluation:
 *
 *  WHERE clauses are evaluated in a recursive loop; initiated by
 *  calling SQL_Statement_EvalWhere.
 *
 *  This function verifies whether a WHERE clause is present; if not,
 *  it returns -1 immediately.
 *
 *  If a clause is present, the function SqlEvalOp is called for
 *  evaluating a single operation. If either op->arg1 or op->arg2
 *  are yet other operations, the function calls itself recursively
 *  until finally a node operation (EQ, GT, ..., IS, LIKE) is
 *  found.
 *
 *  The main problem in evaluating node clauses is determining
 *  the context: Are strings, reals or integers compared? This
 *  decision is done in SqlEvalOp, and, depending on the result,
 *  the function continues to call SqlEvalStringOp, SqlEvalRealOp
 *  or SqlEvalIntegerOp.
 *
 *  The interface to Perl is realized via the sql_eval_t structure.
 *  This structure mainly contains callback hooks and other data
 *  for evaluating parameters or columns.
 *
 **************************************************************************/

/*
 *  Store a cached parameter in val
 */
static void SqlStoreCache(sql_cache_t* cache, sql_val_t* val) {
    switch ((val->type = cache->type)) {
      case SQL_STATEMENT_TYPE_INTEGER:
	val->data.i = cache->data.i;
	break;
      case SQL_STATEMENT_TYPE_REAL:
	val->data.d = cache->data.d;
	break;
      default:
	val->data.str.pPtr = cache->data.str.ptr;
	val->data.str.pLen = cache->data.str.len;
    }
}


/*
 *  Evaluate parameter p; store result in val.
 *  Implements a caching mechanism; cache must be cleared in
 *  SQL_Statement_EvalWhere.
 */
static int SqlEvalParam(sql_stmt_t* stmt, sql_val_t* p, sql_val_t* val) {
    if (p->data.p.cache.type == SQL_STATEMENT_TYPE_PARAM) {
	if ((*(stmt->evalData->eParam))(stmt, p, &p->data.p.cache)  ==  -1) {
	    return -1;
	}
    }
    SqlStoreCache(&p->data.p.cache, val);
    return 1;
}

/*
 *  Evaluate column c; store result in val.
 *  Implements a caching mechanism; cache must be cleared in
 *  SQL_Statement_EvalWhere.
 */
static int SqlEvalColumn(sql_stmt_t* stmt, sql_val_t* c, sql_val_t* val) {
    if (c->data.col.cache.type == SQL_STATEMENT_TYPE_COLUMN) {
        if ((*(stmt->evalData->eColumn))(stmt, c, &c->data.col.cache)
	    ==  -1) {
	    return -1;
	}
    }
    SqlStoreCache(&c->data.col.cache, val);
    return 1;
}


/*
 *  Evaluate an op in string context; internally uses SqlEvalString
 *  for evaluating the strings.
 */
static char* SqlEvalString(sql_val_t* arg, char* buffer, int* l) {
    switch (arg->type) {
      case SQL_STATEMENT_TYPE_INTEGER:
	sprintf(buffer, "%d", arg->data.i);
	*l = strlen(buffer);
	return buffer;
      case SQL_STATEMENT_TYPE_REAL:
	sprintf(buffer, "%f", arg->data.d);
	*l = strlen(buffer);
	return buffer;
      case SQL_STATEMENT_TYPE_STRING:
	*l = arg->data.str.pLen;
	return arg->data.str.pPtr;
      default:
	return NULL;
    }
}

static int SqlEvalStringOp(int o, sql_val_t* arg1, sql_val_t* arg2) {
    char buffer1[32], buffer2[32];
    char* s1, *s2;
    int l1, l2;

    if (!(s1 = SqlEvalString(arg1, buffer1, &l1))
        ||  !(s2 = SqlEvalString(arg2, buffer2, &l2))) {
        return 0;
    }

    switch (o) {
      case SQL_STATEMENT_OPERATOR_EQ:
	return (l1 == l2)  &&  strncmp(s1, s2, l1) == 0;
      case SQL_STATEMENT_OPERATOR_NE:
	return (l1 != l2)  ||  strncmp(s1, s2, l1) != 0;
      case SQL_STATEMENT_OPERATOR_CLIKE:
	return SQL_Statement_Like(s1, l1, s2, l2, 1);
      case SQL_STATEMENT_OPERATOR_LIKE:
	return SQL_Statement_Like(s1, l1, s2, l2, 0);
      default:
	return 0;
    }
}


/*
 *  Evaluate an op in real context; internally uses SqlEvalReal
 *  for evaluating the reals.
 */
static int SqlEvalReal(sql_val_t* arg, double* d) {
    switch (arg->type) {
      case SQL_STATEMENT_TYPE_INTEGER:
	*d = arg->data.i;
	return 1;
      case SQL_STATEMENT_TYPE_REAL:
	*d = arg->data.d;
	return 1;
      case SQL_STATEMENT_TYPE_STRING:
	*d = atof(arg->data.str.pPtr);
	return 1;
      default:
	return 0;
    }
}

static int SqlEvalRealOp(int o, sql_val_t* arg1, sql_val_t* arg2) {
    double d1, d2;

    if (!SqlEvalReal(arg1, &d1)  ||  !SqlEvalReal(arg2, &d2)) {
        return 0;
    }

    switch (o) {
      case SQL_STATEMENT_OPERATOR_EQ:
	return d1 == d2;
      case SQL_STATEMENT_OPERATOR_NE:
	return d1 != d2;
      case SQL_STATEMENT_OPERATOR_GT:
	return d1 > d2;
      case SQL_STATEMENT_OPERATOR_GE:
	return d1 >= d2;
      case SQL_STATEMENT_OPERATOR_LT:
#ifdef DEBUGGING_OP
	printf("Comparing %f and %f => %d\n", d1, d2, (d1 < d2));
#endif
	return d1 < d2;
      case SQL_STATEMENT_OPERATOR_LE:
	return d1 <= d2;
      default:
	return 0;
    }
}


/*
 *  Evaluate an op in integer context; internally uses SqlEvalInteger
 *  for evaluating the integers.
 */
static int SqlEvalInteger(sql_val_t* arg, int* i) {
    switch (arg->type) {
      case SQL_STATEMENT_TYPE_INTEGER:
	*i = arg->data.i;
	return 1;
      case SQL_STATEMENT_TYPE_REAL:
	*i = arg->data.d;
	return 1;
      case SQL_STATEMENT_TYPE_STRING:
	*i = atoi(arg->data.str.pPtr);
	return 1;
      default:
	return 0;
    }
}

static int SqlEvalIntegerOp(int o, sql_val_t* arg1, sql_val_t* arg2) {
    int i1, i2;

    if (!SqlEvalInteger(arg1, &i1)  ||  !SqlEvalInteger(arg2, &i2)) {
        return 0;
    }

    switch (o) {
      case SQL_STATEMENT_OPERATOR_EQ:
	return i1 == i2;
      case SQL_STATEMENT_OPERATOR_NE:
	return i1 != i2;
      case SQL_STATEMENT_OPERATOR_GT:
	return i1 > i2;
      case SQL_STATEMENT_OPERATOR_GE:
	return i1 >= i2;
      case SQL_STATEMENT_OPERATOR_LT:
#ifdef DEBUGGING_OP
	printf("Comparing %d and %d => %d\n", i1, i2, (i1 < i2));
#endif
	return i1 < i2;
      case SQL_STATEMENT_OPERATOR_LE:
	return i1 <= i2;
      default:
	return 0;
    }
}


static int SqlEvalOp(sql_stmt_t* stmt, sql_val_t* val) {
    sql_val_t* arg1 = ((sql_val_t*) stmt->values.data) + val->data.o.arg1;
    sql_val_t* arg2 = ((sql_val_t*) stmt->values.data) + val->data.o.arg2;
    int result;
    sql_val_t arg1Val;
    sql_val_t arg2Val;
    int o_type = val->data.o.opNum;

    if (o_type  ==  SQL_STATEMENT_OPERATOR_AND) {
        int b1, b2;
	if ((b1 = SqlEvalOp(stmt, arg1))  ==  -1) { return -1; }
	if (!b1) {
	    result = 0;
	} else {
	    if ((b2 = SqlEvalOp(stmt, arg2))  ==  -1) { return -1; }
	    result = b2;
	}
    } else if (o_type  ==  SQL_STATEMENT_OPERATOR_OR) {
        int b1, b2;
	if ((b1 = SqlEvalOp(stmt, arg1))  ==  -1) { return -1; }
	if (b1) {
	    result = 1;
	} else {
	    if ((b2 = SqlEvalOp(stmt, arg2))  ==  -1) { return -1; }
	    result = b2;
	}
    } else {
        /*
	 *  If arg1 or arg2 are parameters or columns, evaluate them
	 */
        if (arg1->type  ==  SQL_STATEMENT_TYPE_PARAM) {
	    if (SqlEvalParam(stmt, arg1, &arg1Val)  ==  -1) {
	        return -1;
	    }
	    arg1 = &arg1Val;
	} else if (arg1->type  ==  SQL_STATEMENT_TYPE_COLUMN) {
	    if (SqlEvalColumn(stmt, arg1, &arg1Val)  ==  -1) {
	        return -1;
	    }
	    arg1 = &arg1Val;
	} else if (arg1->type  ==  SQL_STATEMENT_TYPE_STRING) {
	    if (!(arg1->data.str.pPtr = SQL_Statement_PPtr(&arg1->data.str))) {
	        stmt->errMsg = SQL_STATEMENT_ERROR_MEM;
		return -1;
	    }
	}
	if (arg2->type  ==  SQL_STATEMENT_TYPE_PARAM) {
	    if (SqlEvalParam(stmt, arg2, &arg2Val)  ==  -1) {
	        return -1;
	    }
	    arg2 = &arg2Val;
	} else if (arg2->type  ==  SQL_STATEMENT_TYPE_COLUMN) {
	    if (SqlEvalColumn(stmt, arg2, &arg2Val)  ==  -1) {
	        return -1;
	    }
	    arg2 = &arg2Val;
	} else if (arg2->type  ==  SQL_STATEMENT_TYPE_STRING) {
	    if (!(arg2->data.str.pPtr = SQL_Statement_PPtr(&arg2->data.str))) {
	        stmt->errMsg = SQL_STATEMENT_ERROR_MEM;
		return -1;
	    }
	}


	/*
	 *  Choose the context.
	 */
	switch (o_type) {
	  case SQL_STATEMENT_OPERATOR_IS:
	    result = (arg1->type  ==  SQL_STATEMENT_TYPE_NULL) ? 1 : 0;
	    break;
	  case SQL_STATEMENT_OPERATOR_LIKE:
	  case SQL_STATEMENT_OPERATOR_CLIKE:
	    /*  This is always string context  */
	    result = SqlEvalStringOp(o_type, arg1, arg2);
	    break;
	  case SQL_STATEMENT_OPERATOR_EQ:
	  case SQL_STATEMENT_OPERATOR_NE:
	    if (arg1->type == SQL_STATEMENT_TYPE_STRING  ||
		arg2->type == SQL_STATEMENT_TYPE_STRING) {
	        result = SqlEvalStringOp(o_type, arg1, arg2);
	    } else if (arg1->type == SQL_STATEMENT_TYPE_REAL  ||
		arg2->type == SQL_STATEMENT_TYPE_REAL) {
	        result = SqlEvalRealOp(o_type, arg1, arg2);
	    } else {
	        result = SqlEvalIntegerOp(o_type, arg1, arg2);
	    }
	    break;
	  default:
	    /* <, <=, >, >= are always in numeric context */
	    if (arg1->type == SQL_STATEMENT_TYPE_REAL  ||
		arg2->type == SQL_STATEMENT_TYPE_REAL  ||
		(arg1->type == SQL_STATEMENT_TYPE_STRING  &&
		 arg2->type == SQL_STATEMENT_TYPE_STRING)) {
	        result = SqlEvalRealOp(o_type, arg1, arg2);
	    } else {
	        result = SqlEvalIntegerOp(o_type, arg1, arg2);
	    }
	    break;
	}
    }
    if (val->data.o.neg) {
        result = !result;
    }
#ifdef DEBUGGING_OP
    printf("SqlEvalOp: op = %d, result = %d\n", val->data.o.opNum,
	   result);
#endif
    return result;
}


int SQL_Statement_EvalWhere(sql_stmt_t* stmt) {
    int i;
    sql_val_t* val;

    /*
     *  Return TRUE, if no WHERE clause present.
     */
    if (stmt->where == -1) {
        return 1;
    }

    /*
     *  Clear the column and parameter caches
     */
    for (i = 0, val = stmt->values.data;
	 i < stmt->values.currentNum;
	 i++, val++) {
        switch (val->type) {
	  case SQL_STATEMENT_TYPE_PARAM:
	    val->data.p.cache.type = SQL_STATEMENT_TYPE_PARAM;
	    break;
	  case SQL_STATEMENT_TYPE_COLUMN:
	    val->data.col.cache.type = SQL_STATEMENT_TYPE_COLUMN;
	    break;
	}
    }

#ifdef DEBUGGING_OP
    printf("SqlEvalWhere:\n");
#endif
    return SqlEvalOp(stmt, ((sql_val_t*)stmt->values.data) + stmt->where);
}
