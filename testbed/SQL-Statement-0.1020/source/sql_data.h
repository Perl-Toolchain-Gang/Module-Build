#ifndef SQL_STATEMENT_SQL_DATA_H
#define SQL_STATEMENT_SQL_DATA_H 1


#if !defined(NULL)
#define NULL ((void*) 0)
#endif


/*
 *  Known commands
 */
enum {
    SQL_STATEMENT_COMMAND_SELECT,
    SQL_STATEMENT_COMMAND_INSERT,
    SQL_STATEMENT_COMMAND_UPDATE,
    SQL_STATEMENT_COMMAND_DELETE,
    SQL_STATEMENT_COMMAND_CREATE,
    SQL_STATEMENT_COMMAND_DROP
};


/*
 *  Error messages
 */
enum {
    SQL_STATEMENT_ERROR_PARSE,
    SQL_STATEMENT_ERROR_MEM,
    SQL_STATEMENT_ERROR_OUT_OF_BOUNDS,
    SQL_STATEMENT_ERROR_INTERNAL,
    SQL_STATEMENT_ERROR_LIMIT
};

/*
 *  Data types we work with
 */
enum {
    SQL_STATEMENT_TYPE_INTEGER,
    SQL_STATEMENT_TYPE_REAL,
    SQL_STATEMENT_TYPE_STRING,
    SQL_STATEMENT_TYPE_IDENT,
    SQL_STATEMENT_TYPE_NULL,
    SQL_STATEMENT_TYPE_OP,
    SQL_STATEMENT_TYPE_COLUMN,
    SQL_STATEMENT_TYPE_TABLE,
    SQL_STATEMENT_TYPE_PARAM,
    SQL_STATEMENT_TYPE_VAL,
    SQL_STATEMENT_TYPE_ORDER,
    SQL_STATEMENT_TYPE_LIMIT
};


/*
 *  Operators
 */
enum {
    SQL_STATEMENT_OPERATOR_EQ,
    SQL_STATEMENT_OPERATOR_NE,
    SQL_STATEMENT_OPERATOR_GT,
    SQL_STATEMENT_OPERATOR_GE,
    SQL_STATEMENT_OPERATOR_LT,
    SQL_STATEMENT_OPERATOR_LE,
    SQL_STATEMENT_OPERATOR_LIKE,
    SQL_STATEMENT_OPERATOR_CLIKE,
    SQL_STATEMENT_OPERATOR_IS,
    SQL_STATEMENT_OPERATOR_AND,
    SQL_STATEMENT_OPERATOR_OR
};

/*
 *  Various types used by the SQL statement
 */
typedef struct {
    void* data;
    int currentNum;
    int maxNum;
    int elemSize;
} sql_array_t;

typedef struct {
    char* ePtr;		/*  escaped string                                 */
    char* pPtr;		/*  parsed string                                  */
    int eLen;		/*  Length of the escaped string                   */
    int pLen;		/*  Length of the parsed string (-1 if not known)  */
} sql_string_t;

typedef struct {
    int type;
    union {
      int i;
      double d;
      struct {
	  char* ptr;
	  int len;
      } str;
    } data;
} sql_cache_t;

typedef struct {
    int num;
    sql_cache_t cache;
} sql_param_t;

typedef struct {
    char* ptr;
    int len;
} sql_ident_t;

typedef struct {
    sql_ident_t table;
    sql_ident_t column;
    sql_cache_t cache;
} sql_column_t;

typedef struct {
    sql_ident_t table;
} sql_table_t;

typedef struct {
    int opNum;
    int arg1;
    int arg2;
    int neg;
} sql_op_t;

typedef struct {
    union {
        sql_column_t col;
        sql_table_t tbl;
        sql_string_t str;
        sql_ident_t id;
        sql_op_t o;
        sql_param_t p;
        int i;
        double d;
    } data;
   int type;
} sql_val_t;

struct sql_stmt_s;
typedef int (*eval_data_func_t)(struct sql_stmt_s*, sql_val_t*, sql_cache_t*);

typedef struct {
    eval_data_func_t eParam;
    eval_data_func_t eColumn;
} sql_eval_data_t;

typedef struct {
     struct {
         char type_real;
         char type_blob;
         char type_text;
     } create;
     struct {
         char join;
         char clike;
     } select;
} sql_parser_t;

typedef struct sql_stmt_s {
    int command;
    int hasResult;
    int distinct;
    int numParam;
    int errMsg;
    int where;
    char* query;
    int queryLen;
    char* queryPtr;
    char* errPtr;
    sql_array_t values;
    sql_array_t columns;
    sql_array_t tables;
    sql_array_t rowvals;
    sql_array_t orderrows;
    sql_eval_data_t* evalData;
    sql_parser_t* parser;
    long limit_offset;
    long limit_max;
} sql_stmt_t;

typedef struct {
    int column;
} sql_column_list_t;

typedef struct {
    int col;
    int desc;
} sql_order_t;

typedef struct {
    int val;
} sql_rowval_list_t;

typedef struct {
    int table;
} sql_table_list_t;


/*
 *  Prototypes
 */
char* SQL_Statement_PPtr(sql_string_t* str);
int SQL_Statement_Prepare(sql_stmt_t* stmt, char* query, int queryLen);
int SQL_Statement_Finish(sql_stmt_t* stmt);
void SQL_Statement_Destroy(sql_stmt_t* stmt);
char* SQL_Statement_Error(int);
char* SQL_Statement_Command(int);
char* SQL_Statement_Op(int);
int SQL_Statement_Like(const char* s1, int l1, const char* s2, int l2,
		       int case_sensitive);
int SQL_Statement_EvalWhere(sql_stmt_t* stmt);

extern sql_parser_t ansiParser;

#endif /* SQL_STATEMENT_SQL_DATA_H */
