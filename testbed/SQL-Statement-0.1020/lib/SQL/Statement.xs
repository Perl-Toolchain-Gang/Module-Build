/* -*- C -*-
 */

#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include "ppport.h"
#include "sql_data.h"


static sql_parser_t sqlEvalParser = {
    { 1, 1, 1 },
    { 0, 1 }
};


typedef struct {
    sql_eval_data_t ed;
    SV* eval_object;
} my_eval_data_t;


static sql_stmt_t* SV2stmt(SV* self) {
    static STRLEN lna;

    if (SvOK(self)  &&  SvROK(self)
	&& sv_derived_from(self, "SQL::Statement")) {
        HV* hv = (HV*) SvRV(self);
	SV** svp;

	if (SvTYPE(hv) == SVt_PVHV  &&
	    (svp = hv_fetch(hv, "stmt", 4, FALSE))) {
	    if (SvOK(*svp)  &&  SvIOK(*svp)) {
	        return (sql_stmt_t*) SvIV(*svp);
	    }
	}
    }

    croak("%s is not a valid SQL::Statement object", SvPV(self, lna));
    return NULL; /* Just to make the compiler happy ... */
}


static SV* SqlObject(SV* stmtSV, sql_stmt_t* stmt, void* obj, int type) {
    SV* result;
    char* bless_package;

    switch(type) {
      case SQL_STATEMENT_TYPE_INTEGER:
	result = newSViv(((sql_val_t*) obj)->data.i);
#ifdef DEBUGGING_MEMORY_LEAK
	printf("TYPE_INTEGER: Returning %08lx\n", (unsigned long) result);
#endif
        return result;
      case SQL_STATEMENT_TYPE_REAL:
	result = newSVnv(((sql_val_t*) obj)->data.d);
#ifdef DEBUGGING_MEMORY_LEAK
	printf("TYPE_REAL: Returning %08lx\n", (unsigned long) result);
#endif
	return result;
      case SQL_STATEMENT_TYPE_STRING:
	{
	    sql_string_t* str = &((sql_val_t*) obj)->data.str;
	    if (!(str->pPtr = SQL_Statement_PPtr(str))) {
	        croak("Out of memory");
	    }
	    result = newSVpv(str->pPtr, str->pLen);
#ifdef DEBUGGING_MEMORY_LEAK
	    printf("TYPE_STRING: Returning %08lx\n", (unsigned long) result);
#endif
	    return result;
	}
      case SQL_STATEMENT_TYPE_IDENT:
	{
	    HV* hv = newHV();
	    sql_ident_t* id = &((sql_val_t*) obj)->data.id;
	    hv_store(hv, "id", 2, newSVpv(id->ptr, id->len), 0);
	    bless_package = "SQL::Statement::Ident";
	    result = newRV_noinc((SV*) hv);
#ifdef DEBUGGING_MEMORY_LEAK
	    printf("TYPE_IDENT: Returning %08lx\n", (unsigned long) result);
#endif
	    break;
	}
      default:
      case SQL_STATEMENT_TYPE_NULL:
	return &PL_sv_undef;
      case SQL_STATEMENT_TYPE_OP:
	{
	    HV* hv = newHV();
	    sql_op_t* o = &((sql_val_t*) obj)->data.o;
	    hv_store(hv, "arg1", 4, newSViv(o->arg1), 0);
	    hv_store(hv, "arg2", 4, newSViv(o->arg2), 0);
	    hv_store(hv, "op", 2, newSViv(o->opNum), 0);
	    hv_store(hv, "neg", 3, newSViv(o->neg), 0);
	    hv_store(hv, "stmt", 4, stmtSV, 0);
	    bless_package = "SQL::Statement::Op";
	    result = newRV((SV*) hv);
#ifdef DEBUGGING_MEMORY_LEAK
	    printf("TYPE_OP: Returning %08lx\n", (unsigned long) result);
#endif
	    break;
	}
      case SQL_STATEMENT_TYPE_COLUMN:
	{
	    HV* hv = newHV();
	    sql_val_t* val = (sql_val_t*) obj;
	    SV* sv;
	    if (val->data.col.table.ptr) {
	        sv = newSVpv(val->data.col.table.ptr,
			     val->data.col.table.len);
	    } else if (stmt->tables.currentNum > 0) {
	        sql_table_list_t* tl = stmt->tables.data;
		val->data.col.table =
		    ((sql_val_t*) stmt->values.data)[tl->table].data.tbl.table;
		sv = newSVpv(val->data.col.table.ptr,
			     val->data.col.table.len);
	    } else {
	        sv = &PL_sv_undef;
	    }
	    hv_store(hv, "table", 5, sv, 0);
	    if (val->data.col.column.ptr) {
	        sv = newSVpv(val->data.col.column.ptr,
				 val->data.col.column.len);
	    } else {
	        sv = newSVpv("*", 1);
	    }
	    hv_store(hv, "column", 6, sv, 0);
	    bless_package = "SQL::Statement::Column";
	    result = newRV_noinc((SV*) hv);
#ifdef DEBUGGING_MEMORY_LEAK
	    printf("TYPE_COLUMN: Returning %08lx\n", (unsigned long) result);
#endif
	    break;
	}
      case SQL_STATEMENT_TYPE_TABLE:
	{
	    HV* hv = newHV();
	    sql_val_t* val = (sql_val_t*) obj;
	    hv_store(hv, "table", 5, newSVpv(val->data.tbl.table.ptr,
					     val->data.tbl.table.len), 0);
	    bless_package = "SQL::Statement::Table";
	    result = newRV_noinc((SV*) hv);
#ifdef DEBUGGING_MEMORY_LEAK
	    printf("TYPE_TABLE: Returning %08lx\n", (unsigned long) result);
#endif
	    break;
	}
      case SQL_STATEMENT_TYPE_VAL:
	return SqlObject(stmtSV, stmt, obj, ((sql_val_t*) obj)->type);
      case SQL_STATEMENT_TYPE_PARAM:
	{
	    HV* hv = newHV();
	    hv_store(hv, "num", 3, newSViv(((sql_val_t*) obj)->data.p.num), 0);
	    bless_package = "SQL::Statement::Param";
	    result = newRV_noinc((SV*) hv);
#ifdef DEBUGGING_MEMORY_LEAK
	    printf("TYPE_PARAM: Returning %08lx\n", (unsigned long) result);
#endif
	    break;
	}
      case SQL_STATEMENT_TYPE_ORDER:
	{
	    sql_order_t* o = (sql_order_t*) obj;
	    HV* hv = newHV();
	    hv_store(hv, "col", 3,
		     SqlObject(stmtSV, stmt,
			       ((sql_val_t*) stmt->values.data) + o->col,
			       SQL_STATEMENT_TYPE_COLUMN), 0);
	    hv_store(hv, "desc", 4, newSViv(o->desc), 0);
	    bless_package = "SQL::Statement::Order";
	    result = newRV_noinc((SV*) hv);
#ifdef DEBUGGING_MEMORY_LEAK
	    printf("TYPE_ORDER: Returning %08lx\n", (unsigned long) result);
#endif
	    break;
	}
      case SQL_STATEMENT_TYPE_LIMIT:
	{
	    HV* hv = newHV();
	    hv_store(hv, "offset", 3, newSViv(stmt->limit_offset) , 0);
	    hv_store(hv, "limit", 4, newSViv(stmt->limit_max), 0);
	    bless_package = "SQL::Statement::Limit";
	    result = newRV_noinc((SV*) hv);
#ifdef DEBUGGING_MEMORY_LEAK
	    printf("TYPE_LIMIT: Returning %08lx\n", (unsigned long) result);
#endif
	    break;
	}
    }

    return sv_bless(result, gv_stashpv(bless_package, TRUE));
}


static int EvalColumn(sql_stmt_t* stmt, sql_val_t* c, sql_cache_t* val) {
    int count;
    SV* sv;
    SV* table = newSVpv(c->data.col.table.ptr, c->data.col.table.len);
    SV* column = newSVpv(c->data.col.column.ptr, c->data.col.column.len);
    dSP;

#ifdef DEBUGGING_MEMORY_LEAK
    printf("EvalColumn: table = %08lx, column = %08lx\n",
	   (unsigned long) table, (unsigned long) column);
#endif

    PUSHMARK(sp);
    XPUSHs(((my_eval_data_t*) stmt->evalData)->eval_object);
    XPUSHs(table);
    XPUSHs(column);
    PUTBACK;
    count = perl_call_method("column", G_SCALAR);
    SPAGAIN;
    if (!count  ||  !(sv = POPs)  ||  !SvOK(sv)) {
        val->type = SQL_STATEMENT_TYPE_NULL;
    } else if (SvIOK(sv)) {
        val->type = SQL_STATEMENT_TYPE_INTEGER;
	val->data.i = SvIV(sv);
    } else if (SvNOK(sv)) {
        val->type = SQL_STATEMENT_TYPE_REAL;
	val->data.d = SvNV(sv);
    } else {
        STRLEN len;
	val->type = SQL_STATEMENT_TYPE_STRING;
	val->data.str.ptr = SvPV(sv, len);
	SvGROW(sv, len+1);
	val->data.str.ptr = SvPV(sv, len);
	*SvEND(sv) = '\0';
	val->data.str.len = len;
    }
    PUTBACK;
    SvREFCNT_dec(table);
    SvREFCNT_dec(column);
    return 1;
}


static int EvalParam(sql_stmt_t* stmt, sql_val_t* p, sql_cache_t* val) {
    int count;
    SV* sv;
    SV* pNum = newSViv(p->data.p.num);
    dSP;

    PUSHMARK(sp);
    XPUSHs(((my_eval_data_t*) stmt->evalData)->eval_object);
    XPUSHs(pNum);
    PUTBACK;
    count = perl_call_method("param", G_SCALAR);
    SPAGAIN;
    if (!count  ||  !(sv = POPs)  ||  !SvOK(sv)) {
        val->type = SQL_STATEMENT_TYPE_NULL;
    } else if (SvIOK(sv)) {
        val->type = SQL_STATEMENT_TYPE_INTEGER;
	val->data.i = SvIV(sv);
    } else if (SvNOK(sv)) {
        val->type = SQL_STATEMENT_TYPE_REAL;
	val->data.d = SvNV(sv);
    } else {
        STRLEN len;
	val->type = SQL_STATEMENT_TYPE_STRING;
	val->data.str.ptr = SvPV(sv, len);
	SvGROW(sv, len+1);
	val->data.str.ptr = SvPV(sv, len);
	*SvEND(sv) = '\0';
	val->data.str.len = len;
    }
    PUTBACK;
    SvREFCNT_dec(pNum);
    return 1;
}


/***************************************************************************
 *
 *  Simple Array stringification for SQL::Statement::Hash:
 *
 *  Any column starts with a 0x01 byte, followed by the column bytes.
 *  The bytes 0x00-0x03 are escaped by a preceeding 0x02 byte, and
 *  incremented by 1, so NUL bytes are never part of the stringified
 *  array. NULL columns are encoded by a single 0x02 byte (No preceeding
 *  0x01).
 *
 **************************************************************************/

static SV* array2str(AV* av) {
    STRLEN len = 0;
    STRLEN plen;
    char* ptr;
    char* dptr;
    SV** svp;
    int numCols = av_len(av)+1;
    I32 i;
    SV* result;

    for (i = 0;  i < numCols;  i++) {
        ++len;  /*  0x01 byte  */
	svp = av_fetch(av, i, 0);
	if (svp  &&  SvOK(*svp)) {
	    ptr = SvPV(*svp, plen);
	    while (plen--) {
	        if (*ptr < 0x04) {
		    len += 2;
		} else {
		    ++len;
		}
		++ptr;
	    }
	}
    }
    len += 1;  /*  Additional NUL  */

    result = newSV(len);
    SvPOK_on(result);
    SvCUR_set(result, len-1);
    dptr = SvPVX(result);
    for (i = 0;  i < numCols;  i++) {
	svp = av_fetch(av, i, 0);
	if (svp  &&  SvOK(*svp)) {
	    *dptr++ = 0x01;
	    ptr = SvPV(*svp, plen);
	    while (plen--) {
	        if (*ptr < 0x04) {
		    *dptr++ = 0x02;
		    *dptr++ = (*ptr++) + 1;
		} else {
		    *dptr++ = *ptr++;
		}
	    }
	} else {
	    *dptr++ = 0x02;  /* undef */
	}
    }
    *dptr++ = '\0';
    return result;
}

static AV* str2array(SV* sv) {
    AV* av = newAV();
    STRLEN len;
    STRLEN dlen;
    char* ptr = SvPV(sv, len);
    char* dptr;
    STRLEN i = 0, j;
    SV* col;

    if (!sv  ||  !SvOK(sv)) {
        croak("Expected string (stringified array)");
    }

    while (i < len) {
        switch (*ptr++) {
	  case 0x01:
	    j = ++i;
	    dlen = 0;
	    dptr = ptr;
	    while (j < len) {
	        switch (*dptr) {
		  case 0x01:
		    j = len;
		    break;  /* Next column */
		  case 0x02:
		    dptr += 2;
		    j += 2;
		    ++dlen;
		    break;
		  default:
		    ++dptr;
		    ++j;
		    ++dlen;
		}
	    }
	    col = newSV(dlen+1);
	    SvPOK_on(col);
	    SvCUR_set(col, dlen);
	    dptr = SvPVX(col);
	    while (i < len) {
	        if (*ptr == 0x01) {
		    break;  /* Next column  */
		} else if (*ptr == 0x02) {
		    ++ptr;
		    *dptr++ = (*ptr++) - 1;
		    i += 2;
		} else {
		    *dptr++ = *ptr++;
		    ++i;
		}
	    }
	    av_push(av, col);
	    break;
	  case 0x02:
	    av_push(av, &PL_sv_undef);
	    ++i;
	    break;
	  default:
	    croak("Error in stringified array, offset %d: Expected column", i);
	}
    }
    return av;
}


MODULE = SQL::Statement		PACKAGE = SQL::Statement

PROTOTYPES: ENABLE

SV*
new(self, statement, parser=NULL)
    SV* self
    SV* statement
    SV* parser
  PROTOTYPE: $$;$
  CODE:
    {
	STRLEN len;
	char* query;
	sql_stmt_t* stmt;
	SV* rv;
	HV* hv;
	HV* stash;
	STRLEN lna;

	if (!(stmt = malloc(sizeof(*stmt)))) {
	    croak("Out of memory");
	}
	if (SvOK(statement)) {
	    query = SvPV(statement, len);
	} else {
	    query = NULL;
	}

	if (!parser  ||  !SvOK(parser)) {
	    stmt->parser = &sqlEvalParser;
	} else if (!SvROK(parser)  || !sv_derived_from(parser, "SQL::Parser")
		   ||  !SvIOK(SvRV(parser))) {
	    croak("%s is not a valid SQL::Parser object", SvPV(parser, lna));
	} else {
	   stmt->parser = (sql_parser_t*) SvIV(SvRV(parser));
	}
	if (!SQL_Statement_Prepare(stmt, query, len)) {
	    int errMsg = stmt->errMsg;
	    if (errMsg != SQL_STATEMENT_ERROR_PARSE) {
	        free(stmt);
		croak(SQL_Statement_Error(errMsg));
	    }
	    croak("Parse error near %s", stmt->errPtr);
	}

	hv = newHV();
	hv_store(hv, "stmt", 4, newSViv((IV)stmt), 0);
	hv_store(hv, "statement", 6, SvREFCNT_inc(statement), 0);
	hv_store(hv, "params", 6, newRV_noinc((SV*) newAV()), 0);
	rv = newRV_noinc((SV*) hv);
	if (SvROK(self)) {
	    stash = SvSTASH(SvRV(self));
	} else {
	    stash = gv_stashpv(SvPV(self, lna), TRUE);
	}
	RETVAL = sv_bless(rv, stash);
    }
  OUTPUT:
    RETVAL


MODULE = SQL::Statement		PACKAGE = SQL::Statement

void
DESTROY(self)
    SV* self
  CODE:
    {
        sql_stmt_t* stmt = SV2stmt(self);
	SQL_Statement_Destroy(stmt);
	free(stmt);
    }

void
limit(self)
    SV* self
  PROTOTYPE: $
  CODE:
    {
        sql_stmt_t* stmt = SV2stmt(self);
	if (stmt->limit_max == -1) {
	  ST(0) = &PL_sv_undef;
	} else {
	  ST(0) = sv_2mortal(SqlObject(self, stmt, NULL,
				       SQL_STATEMENT_TYPE_LIMIT));
	}
    }

SV*
command(self)
    SV* self
  CODE:
    {
        sql_stmt_t* stmt = SV2stmt(self);
	char* command = SQL_Statement_Command(stmt->command);
	if (!command) {
	    XSRETURN_UNDEF;
	}
	RETVAL = newSVpv(command, 0);
#ifdef DEBUGGING_MEMORY_LEAK
	printf("command: Returning %08lx\n", (unsigned long) command);
#endif
    }
  OUTPUT:
    RETVAL


void
columns(self, column=NULL)
    SV* self
    SV* column
  PROTOTYPE: $;$
  PPCODE:
    {
        sql_stmt_t* stmt = SV2stmt(self);
	if (column  &&  SvOK(column)) {
	    /*
	     *  Retrieve a given column
	     */
	    int i = SvIV(column);
	    sql_column_list_t *col;
	    if (!stmt->columns.data  ||  i < 0  ||
		i > stmt->columns.currentNum) {
	        XSRETURN_UNDEF;
	    }
	    col = ((sql_column_list_t *) stmt->columns.data) + i;
	    EXTEND(sp, 1);
	    ST(0) = sv_2mortal(SqlObject(self, stmt,
					 ((sql_val_t*) stmt->values.data)
					 + col->column,
					 SQL_STATEMENT_TYPE_VAL));
#ifdef DEBUGGING_MEMORY_LEAK
	    printf("columns: Returning %08lx\n", (unsigned long) ST(0));
#endif
	    XSRETURN(1);
	}
	/*
	 *  Retrieve the number of columns or a list of all columns.
	 */
	switch (GIMME_V) {
	  case G_SCALAR:
	    XSRETURN_IV(stmt->columns.currentNum);
	  case G_ARRAY:
	    {
		int i, num = stmt->columns.currentNum;
		sql_column_list_t* col = ((sql_column_list_t *)
					  stmt->columns.data);
		EXTEND(sp, num);
		for (i = 0;  i < num;  i++) {
		    ST(i) = sv_2mortal(SqlObject(self, stmt,
						 ((sql_val_t*) stmt->values.data)
						 + (col++)->column,
						 SQL_STATEMENT_TYPE_VAL));
#ifdef DEBUGGING_MEMORY_LEAK
		    printf("columns: Returning %08lx\n", (unsigned long) ST(i));
#endif
		}
		XSRETURN(num);
	    }
	  case G_VOID:
	    XSRETURN(0);
	  default:
	    XSRETURN_UNDEF;
	}
    }


void
row_values(self, rval=NULL)
    SV* self
    SV* rval
  PROTOTYPE: $;$
  PPCODE:
    {
        sql_stmt_t* stmt = SV2stmt(self);
	if (rval  &&  SvOK(rval)) {
	    /*
	     *  Retrieve a given column
	     */
	    int i = SvIV(rval);
	    sql_rowval_list_t *rv;
	    if (!stmt->rowvals.data  ||  i < 0  ||
		i > stmt->rowvals.currentNum) {
	        XSRETURN_UNDEF;
	    }
	    rv = ((sql_rowval_list_t *) stmt->rowvals.data) + i;
	    if (rv->val == -1) {
	        XSRETURN_UNDEF;
	    }
	    ST(0) = sv_2mortal(SqlObject(self, stmt,
					 ((sql_val_t*) stmt->values.data) + rv->val,
					 SQL_STATEMENT_TYPE_VAL));
#ifdef DEBUGGING_MEMORY_LEAK
	    printf("row_values: Returning %08lx\n", (unsigned long) ST(0));
#endif
	    XSRETURN(1);
	}
	/*
	 *  Retrieve the number of columns or a list of all columns.
	 */
	switch (GIMME_V) {
	  case G_SCALAR:
	    XSRETURN_IV(stmt->rowvals.currentNum);
	  case G_ARRAY:
	    {
		int i, num = stmt->rowvals.currentNum;
		sql_rowval_list_t* rv = ((sql_rowval_list_t *)
					 stmt->rowvals.data);
		EXTEND(sp, num);
		for (i = 0;  i < num;  i++) {
		    if (rv->val == -1) {
		        ST(i) = &PL_sv_undef;
		    } else {
		        ST(i) = sv_2mortal(SqlObject(self, stmt,
						     ((sql_val_t*) stmt->values.data)
						     + (rv++)->val,
						     SQL_STATEMENT_TYPE_VAL));
		    }
#ifdef DEBUGGING_MEMORY_LEAK
		    printf("row_values: Returning %08lx\n", (unsigned long) ST(i));
#endif
		}
		XSRETURN(num);
	    }
	  case G_VOID:
	    XSRETURN(0);
	  default:
	    XSRETURN_UNDEF;
	}
    }


void
tables(self, table=NULL)
    SV* self
    SV* table
  PROTOTYPE: $;$
  PPCODE:
    {
        sql_stmt_t* stmt = SV2stmt(self);
	if (table  &&  SvOK(table)) {
	    /*
	     *  Retrieve a given table
	     */
	    int i = SvIV(table);
	    sql_table_list_t *tbl;
	    if (!stmt->tables.data  ||  i < 0  ||
		i > stmt->tables.currentNum) {
	        XSRETURN_UNDEF;
	    }
	    tbl = ((sql_table_list_t *) stmt->tables.data) + i;
	    ST(0) = sv_2mortal(SqlObject(self, stmt,
					 ((sql_val_t*) stmt->values.data)
					 + tbl->table,
					 SQL_STATEMENT_TYPE_TABLE));
#ifdef DEBUGGING_MEMORY_LEAK
	    printf("tables: Returning %08lx\n", (unsigned long) ST(0));
#endif
	    XSRETURN(1);
	}

	/*
	 *  Retrieve the number of columns or a list of all columns.
	 */
	switch (GIMME_V) {
	  case G_SCALAR:
	    XSRETURN_IV(stmt->tables.currentNum);
	  case G_ARRAY:
	    {
	        int i, num = stmt->tables.currentNum;
		sql_table_list_t* tl
		    = (sql_table_list_t*) stmt->tables.data;
		EXTEND(sp, num);
		for (i = 0;  i < num;  i++) {
		    ST(i) = sv_2mortal(SqlObject(self, stmt,
						 ((sql_val_t *)
						  stmt->values.data)
						 + (tl++)->table,
						 SQL_STATEMENT_TYPE_VAL));
#ifdef DEBUGGING_MEMORY_LEAK
		    printf("tables: Returning %08lx\n", (unsigned long) ST(i));
#endif
		}
		XSRETURN(num);
	    }
	  case G_VOID:
	    XSRETURN(0);
	  default:
	    XSRETURN_UNDEF;
	}
    }


void
order(self, col=NULL)
    SV* self
    SV* col
  PROTOTYPE: $;$
  PPCODE:
    {
        sql_stmt_t* stmt = SV2stmt(self);
	if (col  &&  SvOK(col)) {
	    /*
	     *  Retrieve a given table
	     */
	    int i = SvIV(col);
	    if (!stmt->orderrows.data  ||  i < 0  ||
		i > stmt->orderrows.currentNum) {
	        XSRETURN_UNDEF;
	    }
	    ST(0) = sv_2mortal(SqlObject(self, stmt,
					 ((sql_order_t*) stmt->orderrows.data) + i,
					 SQL_STATEMENT_TYPE_ORDER));
	    XSRETURN(1);
	}

	/*
	 *  Retrieve the number of columns or a list of all columns.
	 */
	switch (GIMME_V) {
	  case G_SCALAR:
	    XSRETURN_IV(stmt->orderrows.currentNum);
	  case G_ARRAY:
	    {
	        int i, num = stmt->orderrows.currentNum;
		sql_order_t* o = (sql_order_t*) stmt->orderrows.data;
		EXTEND(sp, num);
		for (i = 0;  i < num;  i++) {
		    ST(i) = sv_2mortal(SqlObject(self, stmt, o++,
						 SQL_STATEMENT_TYPE_ORDER));
		}
		XSRETURN(num);
	    }
	  case G_VOID:
	    XSRETURN(0);
	  default:
	    XSRETURN_UNDEF;
	}
    }

SV*
where(self)
    SV* self
  PROTOTYPE: $
  CODE:
    {
        sql_stmt_t* stmt = SV2stmt(self);
	if (stmt->command != SQL_STATEMENT_COMMAND_SELECT  &&
	    stmt->command != SQL_STATEMENT_COMMAND_UPDATE  &&
	    stmt->command != SQL_STATEMENT_COMMAND_DELETE) {
	    XSRETURN_UNDEF;
	}
	RETVAL = SqlObject(self, stmt,
			   ((sql_val_t*) stmt->values.data)+stmt->where,
			   SQL_STATEMENT_TYPE_VAL);
#ifdef DEBUGGING_MEMORY_LEAK
	printf("where: Returning %08lx\n", (unsigned long) ST(0));
#endif
    }
  OUTPUT:
    RETVAL


SV*
op(class, op)
    SV* class
    SV* op
  PROTOTYPE: $$
  CODE:
    {
        char* o = SQL_Statement_Op(SvIV(op));
	if (!o) {
	    XSRETURN_UNDEF;
	}
#ifdef DEBUGGING_MEMORY_LEAK
	printf("op: Returning %08lx\n", (unsigned long) ST(0));
#endif
	RETVAL = newSVpv(o, 0);
    }
  OUTPUT:
    RETVAL


bool
distinct(self)
    SV* self
  PROTOTYPE: $
  CODE:
    {
        sql_stmt_t* stmt = SV2stmt(self);
	RETVAL = stmt->distinct;
    }
  OUTPUT:
    RETVAL


void
val(self, num=NULL)
    SV* self
    SV* num
  PROTOTYPE: $$
  PPCODE:
    {
        sql_stmt_t* stmt = SV2stmt(self);
	if (num  &&  SvOK(num)) {
	    IV i = SvIV(num);
	    if (!stmt->values.data  ||  i < 0  ||
		i > stmt->values.currentNum) {
	        XSRETURN_UNDEF;
	    }
	    ST(0) = sv_2mortal(SqlObject(self, stmt,
					 ((sql_val_t*) stmt->values.data)+i,
					 SQL_STATEMENT_TYPE_VAL));
#ifdef DEBUGGING_MEMORY_LEAK
	    printf("val: Returning %08lx\n", (unsigned long) ST(0));
#endif
	    XSRETURN(1);
	}
	switch (GIMME_V) {
	  case G_SCALAR:
	    {
	        XSRETURN_IV(stmt->values.currentNum);
	    }
	  case G_ARRAY:
	    {
	        int i, num = stmt->values.currentNum;
		sql_val_t* val = (sql_val_t*) stmt->values.data;
		EXTEND(sp, num);
		for (i = 0;  i < num;  i++) {
		    ST(i) = sv_2mortal(SqlObject(self, stmt, val++,
						 SQL_STATEMENT_TYPE_VAL));
#ifdef DEBUGGING_MEMORY_LEAK
		    printf("val: Returning %08lx\n", (unsigned long) ST(i));
#endif
		}
		XSRETURN(num);
	    }
	  default:
	    XSRETURN_EMPTY;
	}
    }


void
eval_where(self, evalObject)
    SV* self
    SV* evalObject
  PROTOTYPE: $$
  PPCODE:
    {
        my_eval_data_t myed;
        sql_stmt_t* stmt = SV2stmt(self);
	int result;

	myed.ed.eParam = EvalParam;
	myed.ed.eColumn = EvalColumn;
	myed.eval_object = evalObject;
#ifdef DEBUGGING_MEMORY_LEAK
	printf("eval_where: EvalParam = %08lx, EvalColumn = %08lx, EvalObject = %08lx\n",
	       (unsigned long) myed.ed.eParam,
	       (unsigned long) myed.ed.eColumn,
	       myed.eval_object);
#endif

	stmt->evalData = (sql_eval_data_t*) &myed;
	if ((result = SQL_Statement_EvalWhere(stmt))  ==  -1) {
	    croak("Internal error in evaluation: %s",
		  SQL_Statement_Error(stmt->errMsg));
	}
	if (result) {
	    XSRETURN_YES;
	}
	XSRETURN_NO;
    }


int
params(self)
    SV* self
  PROTOTYPE: $
  CODE:
    {
        sql_stmt_t* stmt = SV2stmt(self);
	RETVAL = stmt->numParam;
    }
  OUTPUT:
    RETVAL


MODULE = SQL::Statement		PACKAGE = SQL::Parser

SV*
dup(class, name=NULL)
    SV* class
    char* name
  PROTOTYPE: $$
  CODE:
    {
        sql_parser_t* parser;
	sql_parser_t* dup;
	HV* stash;
	STRLEN lna;

	if (SvROK(class)) {
	    stash = SvSTASH(SvRV(class));
	} else {
	    stash = gv_stashpv(SvPV(class, lna), TRUE);
	}
        if (!name  ||  strEQ(name, "Ansi")) {
	    parser = &ansiParser;
	} else if (strEQ(name, "SQL::Eval")) {
	    parser = &sqlEvalParser;
	} else {
	    croak("Unknown parser: %s", name);
	}
	New(1000, dup, 1, sql_parser_t);
	Copy(parser, dup, 1, sql_parser_t);
	RETVAL = sv_bless(newRV_noinc(newSViv((IV) dup)), stash);
    }
  OUTPUT:
    RETVAL


void
DESTROY(self)
    SV* self;
  PROTOTYPE: $
  PPCODE:
    {
        STRLEN lna;

        if (!SvOK(self)  ||  !SvROK(self)  ||
	    !sv_derived_from(self, "SQL::Parser")  ||  !SvIOK(SvRV(self))) {
	    croak("%s is not a valid SQL::Parser object", SvPV(self, lna));
	}
	Safefree((sql_parser_t*) SvIV(SvRV(self)));
    }


void
feature(self, set, f, val=NULL)
    SV* self
    SV* set
    SV* f
    SV* val
  PROTOTYPE: $$$;$
  PPCODE:
    {
        STRLEN setLen, fLen;
	char* setName = SvPV(set, setLen);
	char* fName = SvPV(f, fLen);
	char* fPtr = NULL;
	sql_parser_t* parser;
	STRLEN lna;

        if (!SvOK(self)  ||  !SvROK(self)  ||
	    !sv_derived_from(self, "SQL::Parser")  ||  !SvIOK(SvRV(self))) {
	    croak("%s is not a valid SQL::Parser object", SvPV(self, lna));
	}
	parser = (sql_parser_t*) SvIV(SvRV(self));

	if (setLen == 6) {
	    if (strnEQ(setName, "create", 6)) {
	        if (fLen == 9) {
		    if (strnEQ(fName, "type_real", 9)) {
		        fPtr = &parser->create.type_real;
		    } else if (strnEQ(fName, "type_text", 9)) {
		        fPtr = &parser->create.type_text;
		    } else if (strnEQ(fName, "type_blob", 9)) {
		        fPtr = &parser->create.type_blob;
		    }
		}
	    } else if (strnEQ(setName, "select", 6)) {
	        if (fLen == 4) {
		    if (strnEQ(fName, "join", 4)) {
		        fPtr = &parser->select.join;
		    }
		} else if (fLen == 5) {
		    if (strnEQ(fName, "clike", 5)) {
		        fPtr = &parser->select.clike;
		    }
		}
	    }
	}
	if (!fPtr) {
	    croak("Unknown feature: %s.%s", setName, fName);
	}
	if (val  &&  SvOK(val)) {
	    *fPtr = SvTRUE(val) ? 1 : 0;
	}
	if (*fPtr) {
	    XSRETURN_YES;
	}
	XSRETURN_NO;
    }


MODULE = SQL::Statement		PACKAGE = SQL::Statement::Hash

SV*
_array2str(arr)
    SV* arr
  PROTOTYPE: $
  CODE:
    if (!arr  ||  !SvOK(arr)  ||  !SvROK(arr)  ||
	SvTYPE(SvRV(arr)) != SVt_PVAV) {
        croak("_array2str: Expected array ref");
    }
    RETVAL = array2str((AV*) SvRV(arr));
  OUTPUT:
    RETVAL


SV*
_str2array(str)
    SV* str
  PROTOTYPE: $
  CODE:
    RETVAL = newRV_noinc((SV*) str2array(str));
  OUTPUT:
    RETVAL

