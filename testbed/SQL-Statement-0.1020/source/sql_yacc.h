typedef union {
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
} YYSTYPE;
#define	INTEGERVAL	257
#define	STRING	258
#define	REALVAL	259
#define	IDENT	260
#define	NULLVAL	261
#define	PARAM	262
#define	OPERATOR	263
#define	IS	264
#define	AND	265
#define	OR	266
#define	ERROR	267
#define	INSERT	268
#define	UPDATE	269
#define	SELECT	270
#define	DELETE	271
#define	DROP	272
#define	CREATE	273
#define	ALL	274
#define	DISTINCT	275
#define	WHERE	276
#define	ORDER	277
#define	LIMIT	278
#define	ASC	279
#define	DESC	280
#define	FROM	281
#define	INTO	282
#define	BY	283
#define	VALUES	284
#define	SET	285
#define	NOT	286
#define	TABLE	287
#define	CHAR	288
#define	VARCHAR	289
#define	REAL	290
#define	INTEGER	291
#define	PRIMARY	292
#define	KEY	293
#define	BLOB	294
#define	TEXT	295

