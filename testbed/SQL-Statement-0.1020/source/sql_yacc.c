
/*  A Bison parser, made from sql_yacc.y
 by  GNU Bison version 1.27
  */

#define YYBISON 1  /* Identify Bison output.  */

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

#line 4 "sql_yacc.y"


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


#line 23 "sql_yacc.y"
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
#line 37 "sql_yacc.y"


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

#include <stdio.h>

#ifndef __cplusplus
#ifndef __STDC__
#define const
#endif
#endif



#define	YYFINAL		160
#define	YYFLAG		-32768
#define	YYNTBASE	46

#define YYTRANSLATE(x) ((unsigned)(x) <= 295 ? yytranslate[x] : 90)

static const char yytranslate[] = {     0,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,    42,
    43,    45,     2,    44,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     2,     2,     2,     2,     2,     1,     3,     4,     5,     6,
     7,     8,     9,    10,    11,    12,    13,    14,    15,    16,
    17,    18,    19,    20,    21,    22,    23,    24,    25,    26,
    27,    28,    29,    30,    31,    32,    33,    34,    35,    36,
    37,    38,    39,    40,    41
};

#if YYDEBUG != 0
static const short yyprhs[] = {     0,
     0,     2,     4,     6,     8,    10,    12,    16,    24,    26,
    30,    34,    41,    48,    52,    56,    60,    61,    64,    65,
    72,    78,    80,    84,    95,    96,   100,   102,   106,   108,
   111,   114,   115,   118,   123,   132,   138,   143,   147,   153,
   154,   158,   160,   164,   166,   170,   172,   173,   175,   177,
   179,   183,   186,   189,   191,   192,   194,   198,   201,   203,
   204,   207,   208,   209,   210,   211,   213,   217,   219,   223,
   225,   228,   230,   234,   236,   240,   244,   249,   251,   253,
   255,   257,   259,   261,   263,   265
};

static const short yyrhs[] = {    54,
     0,    59,     0,    60,     0,    61,     0,    48,     0,    47,
     0,    18,    33,    74,     0,    19,    33,    74,    42,    49,
    52,    43,     0,    50,     0,    49,    44,    50,     0,    89,
    37,    51,     0,    89,    34,    42,     3,    43,    51,     0,
    89,    35,    42,     3,    43,    51,     0,    89,    36,    51,
     0,    89,    40,    51,     0,    89,    41,    51,     0,     0,
    32,     7,     0,     0,    38,    39,     6,    42,    53,    43,
     0,    38,    39,    42,    53,    43,     0,     6,     0,    53,
    44,     6,     0,    16,    67,    68,    27,    72,    75,    78,
    79,    55,    58,     0,     0,    23,    29,    56,     0,    57,
     0,    56,    44,    57,     0,    88,     0,    88,    25,     0,
    88,    26,     0,     0,    24,     3,     0,    24,     3,    44,
     3,     0,    14,    28,    74,    63,    30,    42,    65,    43,
     0,    15,    74,    31,    62,    75,     0,    17,    27,    74,
    75,     0,    88,     9,    87,     0,    62,    44,    88,     9,
    87,     0,     0,    42,    64,    43,     0,    89,     0,    64,
    44,    89,     0,    66,     0,    65,    44,    66,     0,    87,
     0,     0,    20,     0,    21,     0,    69,     0,    68,    44,
    69,     0,    70,    71,     0,    77,    45,     0,    86,     0,
     0,    73,     0,    72,    44,    73,     0,    74,    76,     0,
     6,     0,     0,    22,    80,     0,     0,     0,     0,     0,
    81,     0,    80,    12,    81,     0,    82,     0,    81,    11,
    82,     0,    83,     0,    32,    83,     0,    84,     0,    42,
    80,    43,     0,    85,     0,    86,     9,    86,     0,    86,
    10,     7,     0,    86,    10,    32,     7,     0,    87,     0,
    88,     0,     3,     0,     5,     0,     4,     0,     7,     0,
     8,     0,     6,     0,    88,     0
};

#endif

#if YYDEBUG != 0
static const short yyrline[] = { 0,
   138,   140,   141,   142,   143,   144,   147,   154,   161,   163,
   166,   168,   169,   170,   172,   174,   178,   180,   183,   185,
   186,   189,   191,   194,   202,   204,   207,   209,   212,   217,
   221,   227,   232,   239,   248,   256,   263,   270,   280,   291,
   293,   296,   298,   301,   303,   306,   316,   318,   319,   322,
   324,   327,   335,   350,   356,   363,   365,   369,   377,   390,
   392,   395,   410,   417,   424,   431,   433,   448,   450,   465,
   467,   478,   480,   483,   493,   507,   520,   558,   560,   563,
   565,   566,   567,   568,   571,   590
};
#endif


#if YYDEBUG != 0 || defined (YYERROR_VERBOSE)

static const char * const yytname[] = {   "$","error","$undefined.","INTEGERVAL",
"STRING","REALVAL","IDENT","NULLVAL","PARAM","OPERATOR","IS","AND","OR","ERROR",
"INSERT","UPDATE","SELECT","DELETE","DROP","CREATE","ALL","DISTINCT","WHERE",
"ORDER","LIMIT","ASC","DESC","FROM","INTO","BY","VALUES","SET","NOT","TABLE",
"CHAR","VARCHAR","REAL","INTEGER","PRIMARY","KEY","BLOB","TEXT","'('","')'",
"','","'*'","sql_expression","drop_expression","create_expression","create_row_commalist",
"create_row","opt_not_null","opt_key","key_row_commalist","select_expression",
"opt_order_by","order_by_item_commalist","order_by_item","opt_limit","insert_expression",
"update_expression","delete_expression","update_item_commalist","insert_item_expression",
"insert_item_commalist","insert_value_commalist","insert_row_value","opt_dist",
"select_item_commalist","select_item","scalar_expression","opt_column","table_reference_commalist",
"table_reference","table","opt_where","opt_range_as","opt_range","opt_group",
"opt_having","conditional_expression","conditional_term","conditional_factor",
"conditional_primary","simple_condition","comparison_condition","row_constructor",
"row_value","row_name","row_list_name", NULL
};
#endif

static const short yyr1[] = {     0,
    46,    46,    46,    46,    46,    46,    47,    48,    49,    49,
    50,    50,    50,    50,    50,    50,    51,    51,    52,    52,
    52,    53,    53,    54,    55,    55,    56,    56,    57,    57,
    57,    58,    58,    58,    59,    60,    61,    62,    62,    63,
    63,    64,    64,    65,    65,    66,    67,    67,    67,    68,
    68,    69,    69,    70,    71,    72,    72,    73,    74,    75,
    75,    76,    77,    78,    79,    80,    80,    81,    81,    82,
    82,    83,    83,    84,    85,    85,    85,    86,    86,    87,
    87,    87,    87,    87,    88,    89
};

static const short yyr2[] = {     0,
     1,     1,     1,     1,     1,     1,     3,     7,     1,     3,
     3,     6,     6,     3,     3,     3,     0,     2,     0,     6,
     5,     1,     3,    10,     0,     3,     1,     3,     1,     2,
     2,     0,     2,     4,     8,     5,     4,     3,     5,     0,
     3,     1,     3,     1,     3,     1,     0,     1,     1,     1,
     3,     2,     2,     1,     0,     1,     3,     2,     1,     0,
     2,     0,     0,     0,     0,     1,     3,     1,     3,     1,
     2,     1,     3,     1,     3,     3,     4,     1,     1,     1,
     1,     1,     1,     1,     1,     1
};

static const short yydefact[] = {     0,
     0,     0,    47,     0,     0,     0,     6,     5,     1,     2,
     3,     4,     0,    59,     0,    48,    49,    63,     0,     0,
     0,    40,     0,    80,    82,    81,    85,    83,    84,     0,
    50,    55,     0,    54,    78,    79,    60,     7,     0,     0,
     0,    60,     0,     0,    63,    52,    53,     0,    37,     0,
     0,    86,    42,     0,     0,    36,     0,    60,    56,    62,
    51,     0,     0,    61,    66,    68,    70,    72,    74,     0,
    19,     9,     0,    41,     0,     0,     0,    38,     0,    64,
    58,    71,     0,     0,     0,     0,     0,     0,     0,     0,
     0,     0,    17,    17,    17,    17,    43,     0,    44,    46,
     0,    57,    65,    73,    67,    69,    75,    76,     0,     0,
    10,     8,     0,     0,     0,    14,    11,    15,    16,    35,
     0,    39,    25,    77,     0,     0,     0,     0,    18,    45,
     0,    32,     0,    22,     0,    17,    17,     0,     0,    24,
     0,    21,     0,    12,    13,    26,    27,    29,    33,    20,
    23,     0,    30,    31,     0,    28,    34,     0,     0,     0
};

static const short yydefgoto[] = {   158,
     7,     8,    71,    72,   116,    90,   135,     9,   132,   146,
   147,   140,    10,    11,    12,    42,    41,    51,    98,    99,
    18,    30,    31,    32,    46,    58,    59,    60,    49,    81,
    33,   103,   123,    64,    65,    66,    67,    68,    69,    70,
    35,    36,    73
};

static const short yypact[] = {    67,
   -10,    19,     0,     3,    10,    22,-32768,-32768,-32768,-32768,
-32768,-32768,    19,-32768,    37,-32768,-32768,    84,    19,    19,
    19,    16,    95,-32768,-32768,-32768,-32768,-32768,-32768,     2,
-32768,-32768,    51,-32768,-32768,-32768,    80,-32768,    61,    95,
    75,   -20,    97,    19,    84,-32768,-32768,     8,-32768,    95,
    13,-32768,-32768,    62,    95,-32768,    90,   -13,-32768,-32768,
-32768,    30,     8,    96,    98,-32768,-32768,-32768,-32768,    53,
     7,-32768,    39,-32768,    95,    90,   101,-32768,    19,-32768,
-32768,-32768,    11,     8,     8,    84,    12,    68,    95,    69,
    71,    72,    79,    79,    79,    79,-32768,    21,-32768,-32768,
    90,-32768,-32768,-32768,    98,-32768,-32768,-32768,   109,    -1,
-32768,-32768,   114,   115,   112,-32768,-32768,-32768,-32768,-32768,
    90,-32768,    99,-32768,    78,   117,    81,    82,-32768,-32768,
    92,   102,   117,-32768,    27,    79,    79,    95,   124,-32768,
    34,-32768,   122,-32768,-32768,    86,-32768,    74,    87,-32768,
-32768,    95,-32768,-32768,   129,-32768,-32768,   133,   134,-32768
};

static const short yypgoto[] = {-32768,
-32768,-32768,-32768,    46,   -88,-32768,     4,-32768,-32768,-32768,
   -16,-32768,-32768,-32768,-32768,-32768,-32768,-32768,-32768,    17,
-32768,-32768,    94,-32768,-32768,-32768,    63,    40,   -32,-32768,
-32768,-32768,-32768,    77,    57,    58,    83,-32768,-32768,   -17,
   -54,   -23,   -36
};


#define	YYLAST		145


static const short yytable[] = {    43,
    34,    48,    78,    53,   125,   117,   118,   119,    48,    56,
    24,    25,    26,    27,    28,    29,    52,    13,   108,    16,
    17,   100,    84,    55,    14,    80,    52,    34,    44,    19,
    79,    77,    24,    25,    26,    27,    28,    29,    97,    62,
   126,    15,    20,   109,    88,    45,   122,   144,   145,    63,
    89,    52,    22,   104,    21,    74,    75,    40,    37,    38,
    39,    86,    87,   120,   121,    52,   100,    23,   107,   142,
   143,    63,    91,    92,    93,    94,   150,   143,    95,    96,
     1,     2,     3,     4,     5,     6,    24,    25,    26,    27,
    28,    29,    24,    25,    26,    47,    28,    29,   153,   154,
    27,    48,    50,    76,    54,    57,   110,    84,    85,   101,
   115,   112,   113,   114,   148,   124,   127,   128,   129,   133,
   138,   131,   134,   136,   137,   139,   149,   151,   148,   152,
   155,   157,   159,   160,   111,   156,   141,   130,    61,    83,
   105,   102,   106,     0,    82
};

static const short yycheck[] = {    23,
    18,    22,    57,    40,     6,    94,    95,    96,    22,    42,
     3,     4,     5,     6,     7,     8,    40,    28,     7,    20,
    21,    76,    12,    44,     6,    58,    50,    45,    27,    27,
    44,    55,     3,     4,     5,     6,     7,     8,    75,    32,
    42,     2,    33,    32,    38,    44,   101,   136,   137,    42,
    44,    75,    13,    43,    33,    43,    44,    42,    19,    20,
    21,     9,    10,    43,    44,    89,   121,    31,    86,    43,
    44,    42,    34,    35,    36,    37,    43,    44,    40,    41,
    14,    15,    16,    17,    18,    19,     3,     4,     5,     6,
     7,     8,     3,     4,     5,    45,     7,     8,    25,    26,
     6,    22,    42,    42,    30,     9,    39,    12,    11,     9,
    32,    43,    42,    42,   138,     7,     3,     3,     7,    42,
    29,    23,     6,    43,    43,    24,     3,     6,   152,    44,
    44,     3,     0,     0,    89,   152,   133,   121,    45,    63,
    84,    79,    85,    -1,    62
};
#define YYPURE 1

/* -*-C-*-  Note some compilers choke on comments on `#line' lines.  */
#line 3 "/usr/local/gnu/share/bison.simple"
/* This file comes from bison-1.27.  */

/* Skeleton output parser for bison,
   Copyright (C) 1984, 1989, 1990 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330,
   Boston, MA 02111-1307, USA.  */

/* As a special exception, when this file is copied by Bison into a
   Bison output file, you may use that output file without restriction.
   This special exception was added by the Free Software Foundation
   in version 1.24 of Bison.  */

/* This is the parser code that is written into each bison parser
  when the %semantic_parser declaration is not specified in the grammar.
  It was written by Richard Stallman by simplifying the hairy parser
  used when %semantic_parser is specified.  */

#ifndef YYSTACK_USE_ALLOCA
#ifdef alloca
#define YYSTACK_USE_ALLOCA
#else /* alloca not defined */
#ifdef __GNUC__
#define YYSTACK_USE_ALLOCA
#define alloca __builtin_alloca
#else /* not GNU C.  */
#if (!defined (__STDC__) && defined (sparc)) || defined (__sparc__) || defined (__sparc) || defined (__sgi) || (defined (__sun) && defined (__i386))
#define YYSTACK_USE_ALLOCA
#include <alloca.h>
#else /* not sparc */
/* We think this test detects Watcom and Microsoft C.  */
/* This used to test MSDOS, but that is a bad idea
   since that symbol is in the user namespace.  */
#if (defined (_MSDOS) || defined (_MSDOS_)) && !defined (__TURBOC__)
#if 0 /* No need for malloc.h, which pollutes the namespace;
	 instead, just don't use alloca.  */
#include <malloc.h>
#endif
#else /* not MSDOS, or __TURBOC__ */
#if defined(_AIX)
/* I don't know what this was needed for, but it pollutes the namespace.
   So I turned it off.   rms, 2 May 1997.  */
/* #include <malloc.h>  */
 #pragma alloca
#define YYSTACK_USE_ALLOCA
#else /* not MSDOS, or __TURBOC__, or _AIX */
#if 0
#ifdef __hpux /* haible@ilog.fr says this works for HPUX 9.05 and up,
		 and on HPUX 10.  Eventually we can turn this on.  */
#define YYSTACK_USE_ALLOCA
#define alloca __builtin_alloca
#endif /* __hpux */
#endif
#endif /* not _AIX */
#endif /* not MSDOS, or __TURBOC__ */
#endif /* not sparc */
#endif /* not GNU C */
#endif /* alloca not defined */
#endif /* YYSTACK_USE_ALLOCA not defined */

#ifdef YYSTACK_USE_ALLOCA
#define YYSTACK_ALLOC alloca
#else
#define YYSTACK_ALLOC malloc
#endif

/* Note: there must be only one dollar sign in this file.
   It is replaced by the list of actions, each action
   as one case of the switch.  */

#define yyerrok		(yyerrstatus = 0)
#define yyclearin	(yychar = YYEMPTY)
#define YYEMPTY		-2
#define YYEOF		0
#define YYACCEPT	goto yyacceptlab
#define YYABORT 	goto yyabortlab
#define YYERROR		goto yyerrlab1
/* Like YYERROR except do call yyerror.
   This remains here temporarily to ease the
   transition to the new meaning of YYERROR, for GCC.
   Once GCC version 2 has supplanted version 1, this can go.  */
#define YYFAIL		goto yyerrlab
#define YYRECOVERING()  (!!yyerrstatus)
#define YYBACKUP(token, value) \
do								\
  if (yychar == YYEMPTY && yylen == 1)				\
    { yychar = (token), yylval = (value);			\
      yychar1 = YYTRANSLATE (yychar);				\
      YYPOPSTACK;						\
      goto yybackup;						\
    }								\
  else								\
    { yyerror ("syntax error: cannot back up"); YYERROR; }	\
while (0)

#define YYTERROR	1
#define YYERRCODE	256

#ifndef YYPURE
#define YYLEX		yylex()
#endif

#ifdef YYPURE
#ifdef YYLSP_NEEDED
#ifdef YYLEX_PARAM
#define YYLEX		yylex(&yylval, &yylloc, YYLEX_PARAM)
#else
#define YYLEX		yylex(&yylval, &yylloc)
#endif
#else /* not YYLSP_NEEDED */
#ifdef YYLEX_PARAM
#define YYLEX		yylex(&yylval, YYLEX_PARAM)
#else
#define YYLEX		yylex(&yylval)
#endif
#endif /* not YYLSP_NEEDED */
#endif

/* If nonreentrant, generate the variables here */

#ifndef YYPURE

int	yychar;			/*  the lookahead symbol		*/
YYSTYPE	yylval;			/*  the semantic value of the		*/
				/*  lookahead symbol			*/

#ifdef YYLSP_NEEDED
YYLTYPE yylloc;			/*  location data for the lookahead	*/
				/*  symbol				*/
#endif

int yynerrs;			/*  number of parse errors so far       */
#endif  /* not YYPURE */

#if YYDEBUG != 0
int yydebug;			/*  nonzero means print parse trace	*/
/* Since this is uninitialized, it does not stop multiple parsers
   from coexisting.  */
#endif

/*  YYINITDEPTH indicates the initial size of the parser's stacks	*/

#ifndef	YYINITDEPTH
#define YYINITDEPTH 200
#endif

/*  YYMAXDEPTH is the maximum size the stacks can grow to
    (effective only if the built-in stack extension method is used).  */

#if YYMAXDEPTH == 0
#undef YYMAXDEPTH
#endif

#ifndef YYMAXDEPTH
#define YYMAXDEPTH 10000
#endif

/* Define __yy_memcpy.  Note that the size argument
   should be passed with type unsigned int, because that is what the non-GCC
   definitions require.  With GCC, __builtin_memcpy takes an arg
   of type size_t, but it can handle unsigned int.  */

#if __GNUC__ > 1		/* GNU C and GNU C++ define this.  */
#define __yy_memcpy(TO,FROM,COUNT)	__builtin_memcpy(TO,FROM,COUNT)
#else				/* not GNU C or C++ */
#ifndef __cplusplus

/* This is the most reliable way to avoid incompatibilities
   in available built-in functions on various systems.  */
static void
__yy_memcpy (to, from, count)
     char *to;
     char *from;
     unsigned int count;
{
  register char *f = from;
  register char *t = to;
  register int i = count;

  while (i-- > 0)
    *t++ = *f++;
}

#else /* __cplusplus */

/* This is the most reliable way to avoid incompatibilities
   in available built-in functions on various systems.  */
static void
__yy_memcpy (char *to, char *from, unsigned int count)
{
  register char *t = to;
  register char *f = from;
  register int i = count;

  while (i-- > 0)
    *t++ = *f++;
}

#endif
#endif

#line 216 "/usr/local/gnu/share/bison.simple"

/* The user can define YYPARSE_PARAM as the name of an argument to be passed
   into yyparse.  The argument should have type void *.
   It should actually point to an object.
   Grammar actions can access the variable by casting it
   to the proper pointer type.  */

#ifdef YYPARSE_PARAM
#ifdef __cplusplus
#define YYPARSE_PARAM_ARG void *YYPARSE_PARAM
#define YYPARSE_PARAM_DECL
#else /* not __cplusplus */
#define YYPARSE_PARAM_ARG YYPARSE_PARAM
#define YYPARSE_PARAM_DECL void *YYPARSE_PARAM;
#endif /* not __cplusplus */
#else /* not YYPARSE_PARAM */
#define YYPARSE_PARAM_ARG
#define YYPARSE_PARAM_DECL
#endif /* not YYPARSE_PARAM */

/* Prevent warning if -Wstrict-prototypes.  */
#ifdef __GNUC__
#ifdef YYPARSE_PARAM
int yyparse (void *);
#else
int yyparse(void* stmt);
#endif
#endif

int
yyparse(YYPARSE_PARAM_ARG)
     YYPARSE_PARAM_DECL
{
  register int yystate;
  register int yyn;
  register short *yyssp;
  register YYSTYPE *yyvsp;
  int yyerrstatus;	/*  number of tokens to shift before error messages enabled */
  int yychar1 = 0;		/*  lookahead token as an internal (translated) token number */

  short	yyssa[YYINITDEPTH];	/*  the state stack			*/
  YYSTYPE yyvsa[YYINITDEPTH];	/*  the semantic value stack		*/

  short *yyss = yyssa;		/*  refer to the stacks thru separate pointers */
  YYSTYPE *yyvs = yyvsa;	/*  to allow yyoverflow to reallocate them elsewhere */

#ifdef YYLSP_NEEDED
  YYLTYPE yylsa[YYINITDEPTH];	/*  the location stack			*/
  YYLTYPE *yyls = yylsa;
  YYLTYPE *yylsp;

#define YYPOPSTACK   (yyvsp--, yyssp--, yylsp--)
#else
#define YYPOPSTACK   (yyvsp--, yyssp--)
#endif

  int yystacksize = YYINITDEPTH;
  int yyfree_stacks = 0;

#ifdef YYPURE
  int yychar;
  YYSTYPE yylval;
  int yynerrs;
#ifdef YYLSP_NEEDED
  YYLTYPE yylloc;
#endif
#endif

  YYSTYPE yyval;		/*  the variable used to return		*/
				/*  semantic values from the action	*/
				/*  routines				*/

  int yylen;

#if YYDEBUG != 0
  if (yydebug)
    fprintf(stderr, "Starting parse\n");
#endif

  yystate = 0;
  yyerrstatus = 0;
  yynerrs = 0;
  yychar = YYEMPTY;		/* Cause a token to be read.  */

  /* Initialize stack pointers.
     Waste one element of value and location stack
     so that they stay on the same level as the state stack.
     The wasted elements are never initialized.  */

  yyssp = yyss - 1;
  yyvsp = yyvs;
#ifdef YYLSP_NEEDED
  yylsp = yyls;
#endif

/* Push a new state, which is found in  yystate  .  */
/* In all cases, when you get here, the value and location stacks
   have just been pushed. so pushing a state here evens the stacks.  */
yynewstate:

  *++yyssp = yystate;

  if (yyssp >= yyss + yystacksize - 1)
    {
      /* Give user a chance to reallocate the stack */
      /* Use copies of these so that the &'s don't force the real ones into memory. */
      YYSTYPE *yyvs1 = yyvs;
      short *yyss1 = yyss;
#ifdef YYLSP_NEEDED
      YYLTYPE *yyls1 = yyls;
#endif

      /* Get the current used size of the three stacks, in elements.  */
      int size = yyssp - yyss + 1;

#ifdef yyoverflow
      /* Each stack pointer address is followed by the size of
	 the data in use in that stack, in bytes.  */
#ifdef YYLSP_NEEDED
      /* This used to be a conditional around just the two extra args,
	 but that might be undefined if yyoverflow is a macro.  */
      yyoverflow("parser stack overflow",
		 &yyss1, size * sizeof (*yyssp),
		 &yyvs1, size * sizeof (*yyvsp),
		 &yyls1, size * sizeof (*yylsp),
		 &yystacksize);
#else
      yyoverflow("parser stack overflow",
		 &yyss1, size * sizeof (*yyssp),
		 &yyvs1, size * sizeof (*yyvsp),
		 &yystacksize);
#endif

      yyss = yyss1; yyvs = yyvs1;
#ifdef YYLSP_NEEDED
      yyls = yyls1;
#endif
#else /* no yyoverflow */
      /* Extend the stack our own way.  */
      if (yystacksize >= YYMAXDEPTH)
	{
	  yyerror("parser stack overflow");
	  if (yyfree_stacks)
	    {
	      free (yyss);
	      free (yyvs);
#ifdef YYLSP_NEEDED
	      free (yyls);
#endif
	    }
	  return 2;
	}
      yystacksize *= 2;
      if (yystacksize > YYMAXDEPTH)
	yystacksize = YYMAXDEPTH;
#ifndef YYSTACK_USE_ALLOCA
      yyfree_stacks = 1;
#endif
      yyss = (short *) YYSTACK_ALLOC (yystacksize * sizeof (*yyssp));
      __yy_memcpy ((char *)yyss, (char *)yyss1,
		   size * (unsigned int) sizeof (*yyssp));
      yyvs = (YYSTYPE *) YYSTACK_ALLOC (yystacksize * sizeof (*yyvsp));
      __yy_memcpy ((char *)yyvs, (char *)yyvs1,
		   size * (unsigned int) sizeof (*yyvsp));
#ifdef YYLSP_NEEDED
      yyls = (YYLTYPE *) YYSTACK_ALLOC (yystacksize * sizeof (*yylsp));
      __yy_memcpy ((char *)yyls, (char *)yyls1,
		   size * (unsigned int) sizeof (*yylsp));
#endif
#endif /* no yyoverflow */

      yyssp = yyss + size - 1;
      yyvsp = yyvs + size - 1;
#ifdef YYLSP_NEEDED
      yylsp = yyls + size - 1;
#endif

#if YYDEBUG != 0
      if (yydebug)
	fprintf(stderr, "Stack size increased to %d\n", yystacksize);
#endif

      if (yyssp >= yyss + yystacksize - 1)
	YYABORT;
    }

#if YYDEBUG != 0
  if (yydebug)
    fprintf(stderr, "Entering state %d\n", yystate);
#endif

  goto yybackup;
 yybackup:

/* Do appropriate processing given the current state.  */
/* Read a lookahead token if we need one and don't already have one.  */
/* yyresume: */

  /* First try to decide what to do without reference to lookahead token.  */

  yyn = yypact[yystate];
  if (yyn == YYFLAG)
    goto yydefault;

  /* Not known => get a lookahead token if don't already have one.  */

  /* yychar is either YYEMPTY or YYEOF
     or a valid token in external form.  */

  if (yychar == YYEMPTY)
    {
#if YYDEBUG != 0
      if (yydebug)
	fprintf(stderr, "Reading a token: ");
#endif
      yychar = YYLEX;
    }

  /* Convert token to internal form (in yychar1) for indexing tables with */

  if (yychar <= 0)		/* This means end of input. */
    {
      yychar1 = 0;
      yychar = YYEOF;		/* Don't call YYLEX any more */

#if YYDEBUG != 0
      if (yydebug)
	fprintf(stderr, "Now at end of input.\n");
#endif
    }
  else
    {
      yychar1 = YYTRANSLATE(yychar);

#if YYDEBUG != 0
      if (yydebug)
	{
	  fprintf (stderr, "Next token is %d (%s", yychar, yytname[yychar1]);
	  /* Give the individual parser a way to print the precise meaning
	     of a token, for further debugging info.  */
#ifdef YYPRINT
	  YYPRINT (stderr, yychar, yylval);
#endif
	  fprintf (stderr, ")\n");
	}
#endif
    }

  yyn += yychar1;
  if (yyn < 0 || yyn > YYLAST || yycheck[yyn] != yychar1)
    goto yydefault;

  yyn = yytable[yyn];

  /* yyn is what to do for this token type in this state.
     Negative => reduce, -yyn is rule number.
     Positive => shift, yyn is new state.
       New state is final state => don't bother to shift,
       just return success.
     0, or most negative number => error.  */

  if (yyn < 0)
    {
      if (yyn == YYFLAG)
	goto yyerrlab;
      yyn = -yyn;
      goto yyreduce;
    }
  else if (yyn == 0)
    goto yyerrlab;

  if (yyn == YYFINAL)
    YYACCEPT;

  /* Shift the lookahead token.  */

#if YYDEBUG != 0
  if (yydebug)
    fprintf(stderr, "Shifting token %d (%s), ", yychar, yytname[yychar1]);
#endif

  /* Discard the token being shifted unless it is eof.  */
  if (yychar != YYEOF)
    yychar = YYEMPTY;

  *++yyvsp = yylval;
#ifdef YYLSP_NEEDED
  *++yylsp = yylloc;
#endif

  /* count tokens shifted since error; after three, turn off error status.  */
  if (yyerrstatus) yyerrstatus--;

  yystate = yyn;
  goto yynewstate;

/* Do the default action for the current state.  */
yydefault:

  yyn = yydefact[yystate];
  if (yyn == 0)
    goto yyerrlab;

/* Do a reduction.  yyn is the number of a rule to reduce with.  */
yyreduce:
  yylen = yyr2[yyn];
  if (yylen > 0)
    yyval = yyvsp[1-yylen]; /* implement default value of the action */

#if YYDEBUG != 0
  if (yydebug)
    {
      int i;

      fprintf (stderr, "Reducing via rule %d (line %d), ",
	       yyn, yyrline[yyn]);

      /* Print the symbols being reduced, and their result.  */
      for (i = yyprhs[yyn]; yyrhs[i] > 0; i++)
	fprintf (stderr, "%s ", yytname[yyrhs[i]]);
      fprintf (stderr, " -> %s\n", yytname[yyr1[yyn]]);
    }
#endif


  switch (yyn) {

case 7:
#line 149 "sql_yacc.y"
{ ((sql_stmt_t*) stmt)->command = SQL_STATEMENT_COMMAND_DROP;
      ((sql_stmt_t*) stmt)->hasResult = 0;
    ;
    break;}
case 8:
#line 156 "sql_yacc.y"
{ ((sql_stmt_t*) stmt)->command = SQL_STATEMENT_COMMAND_CREATE;
      ((sql_stmt_t*) stmt)->hasResult = 0;
    ;
    break;}
case 10:
#line 163 "sql_yacc.y"
{ yyval.scalar_val = yyvsp[0].scalar_val ;
    break;}
case 14:
#line 171 "sql_yacc.y"
{ YFEATURE(create, type_real); ;
    break;}
case 15:
#line 173 "sql_yacc.y"
{ YFEATURE(create, type_blob); ;
    break;}
case 16:
#line 175 "sql_yacc.y"
{ YFEATURE(create, type_text); ;
    break;}
case 23:
#line 191 "sql_yacc.y"
{ yyval.ident_val = yyvsp[0].ident_val ;
    break;}
case 24:
#line 197 "sql_yacc.y"
{ ((sql_stmt_t*) stmt)->command = SQL_STATEMENT_COMMAND_SELECT;
      ((sql_stmt_t*) stmt)->hasResult = 1;
    ;
    break;}
case 29:
#line 214 "sql_yacc.y"
{ sql_order_t o; o.desc = 0; o.col = yyvsp[0].scalar_val;
      if ((yyval.scalar_val = _AllocOrderRow(stmt, &o))  ==  -1) { YYABORT; }
    ;
    break;}
case 30:
#line 218 "sql_yacc.y"
{ sql_order_t o; o.desc = 0; o.col = yyvsp[-1].scalar_val;
      if ((yyval.scalar_val = _AllocOrderRow(stmt, &o))  ==  -1) { YYABORT; }
    ;
    break;}
case 31:
#line 222 "sql_yacc.y"
{ sql_order_t o; o.desc = 1; o.col = yyvsp[-1].scalar_val;
      if ((yyval.scalar_val = _AllocOrderRow(stmt, &o))  ==  -1) { YYABORT; }
    ;
    break;}
case 32:
#line 229 "sql_yacc.y"
{ ((sql_stmt_t*) stmt)->limit_offset = -1;
      ((sql_stmt_t*) stmt)->limit_max = -1;
    ;
    break;}
case 33:
#line 233 "sql_yacc.y"
{ if (yyvsp[0].int_val < 0) {
        ((sql_stmt_t*) stmt)->errMsg = SQL_STATEMENT_ERROR_LIMIT;
      }
      ((sql_stmt_t*) stmt)->limit_offset = 0;
      ((sql_stmt_t*) stmt)->limit_max = yyvsp[0].int_val;
    ;
    break;}
case 34:
#line 240 "sql_yacc.y"
{ if (yyvsp[-2].int_val < 0  ||  yyvsp[0].int_val < 0) {
        ((sql_stmt_t*) stmt)->errMsg = SQL_STATEMENT_ERROR_LIMIT;
      }
      ((sql_stmt_t*) stmt)->limit_offset = yyvsp[-2].int_val;
      ((sql_stmt_t*) stmt)->limit_max = yyvsp[0].int_val;
    ;
    break;}
case 35:
#line 251 "sql_yacc.y"
{ ((sql_stmt_t*) stmt)->command = SQL_STATEMENT_COMMAND_INSERT;
      ((sql_stmt_t*) stmt)->hasResult = 0;
    ;
    break;}
case 36:
#line 258 "sql_yacc.y"
{ ((sql_stmt_t*) stmt)->command = SQL_STATEMENT_COMMAND_UPDATE;
      ((sql_stmt_t*) stmt)->hasResult = 0;
    ;
    break;}
case 37:
#line 265 "sql_yacc.y"
{ ((sql_stmt_t*) stmt)->command = SQL_STATEMENT_COMMAND_DELETE;
      ((sql_stmt_t*) stmt)->hasResult = 0;
    ;
    break;}
case 38:
#line 272 "sql_yacc.y"
{ sql_rowval_list_t rowVal;
      sql_column_list_t column;
      if (yyvsp[-1].operator != SQL_STATEMENT_OPERATOR_EQ) { YYABORT; }
      column.column = yyvsp[-2].scalar_val;
      if ((yyval.scalar_val = _AllocColumnList(stmt, &column)) == -1) { YYABORT; }
      rowVal.val = yyvsp[0].scalar_val;
      if (_AllocRowValList(stmt, &rowVal) == -1) { YYABORT; }
    ;
    break;}
case 39:
#line 281 "sql_yacc.y"
{ sql_rowval_list_t rowVal;
      sql_column_list_t column;
      if (yyvsp[-1].operator != SQL_STATEMENT_OPERATOR_EQ) { YYABORT; }
      column.column = yyvsp[-2].scalar_val;
      if ((yyval.scalar_val = _AllocColumnList(stmt, &column)) == -1) { YYABORT; }
      rowVal.val = yyvsp[0].scalar_val;
      if (_AllocRowValList(stmt, &rowVal) == -1) { YYABORT; }
    ;
    break;}
case 43:
#line 298 "sql_yacc.y"
{ yyval.scalar_val = yyvsp[0].scalar_val ;
    break;}
case 45:
#line 303 "sql_yacc.y"
{ yyval.scalar_val = yyvsp[0].scalar_val ;
    break;}
case 46:
#line 308 "sql_yacc.y"
{ sql_rowval_list_t rowVal;
      rowVal.val = yyvsp[0].scalar_val;
      if ((yyval.scalar_val = _AllocRowValList(stmt, &rowVal)) == -1) {
	  YYABORT;
      }
    ;
    break;}
case 47:
#line 317 "sql_yacc.y"
{ ((sql_stmt_t*) stmt)->distinct = 0; ;
    break;}
case 48:
#line 318 "sql_yacc.y"
{ ((sql_stmt_t*) stmt)->distinct = 0; ;
    break;}
case 49:
#line 319 "sql_yacc.y"
{ ((sql_stmt_t*) stmt)->distinct = 1; ;
    break;}
case 52:
#line 329 "sql_yacc.y"
{ sql_column_list_t column;
      column.column = yyvsp[-1].scalar_val;
      if ((yyval.column = _AllocColumnList(stmt, &column)) == -1) {
	  YYABORT;
      }
    ;
    break;}
case 53:
#line 336 "sql_yacc.y"
{ sql_column_t col;
      sql_column_list_t column;

      col.table.ptr = NULL;
      col.column.ptr = NULL;
      if ((column.column = _AllocColumn(stmt, &col)) == -1) {
	  YYABORT;
      }
      if ((yyval.column = _AllocColumnList(stmt, &column)) == -1) {
	  YYABORT;
      }
    ;
    break;}
case 57:
#line 366 "sql_yacc.y"
{ YFEATURE(select, join); ;
    break;}
case 59:
#line 378 "sql_yacc.y"
{ sql_table_t table;
          sql_table_list_t tl;
	  table.table = yyvsp[0].ident_val;
	  if ((tl.table = _AllocTable(stmt, &table)) == -1) {
	      YYABORT;
	  }
	  if ((yyval.val = _AllocTableList(stmt, &tl)) == -1) {
	      YYABORT;
	  }
	;
    break;}
case 60:
#line 391 "sql_yacc.y"
{ ((sql_stmt_t*) stmt)->where = -1; ;
    break;}
case 61:
#line 392 "sql_yacc.y"
{ ((sql_stmt_t*) stmt)->where = yyvsp[0].bool_val; ;
    break;}
case 67:
#line 434 "sql_yacc.y"
{ sql_op_t o;
      o.arg1 = yyvsp[-2].bool_val;
      o.opNum = SQL_STATEMENT_OPERATOR_OR;
      o.arg2 = yyvsp[0].bool_val;
      o.neg = 0;
      if ((yyval.bool_val = _AllocOp(stmt, &o)) == -1) {
	  YYABORT;
      }
#ifdef YYDEBUG
      printf("OR operator: %d OR %d -> %d\n", yyvsp[-2].bool_val, yyvsp[0].bool_val, yyval.bool_val);
#endif
    ;
    break;}
case 69:
#line 451 "sql_yacc.y"
{ sql_op_t o;
      o.arg1 = yyvsp[-2].bool_val;
      o.opNum = SQL_STATEMENT_OPERATOR_AND;
      o.arg2 = yyvsp[0].bool_val;
      o.neg = 0;
      if ((yyval.bool_val = _AllocOp(stmt, &o)) == -1) {
	  YYABORT;
      }
#ifdef YYDEBUG
      printf("AND operator: %d AND %d -> %d\n", yyvsp[-2].bool_val, yyvsp[0].bool_val, yyval.bool_val);
#endif
    ;
    break;}
case 71:
#line 468 "sql_yacc.y"
{ sql_val_t* o = ((sql_val_t*) ((sql_stmt_t*) stmt)->values.data)+yyvsp[0].bool_val;
      if (o->type != SQL_STATEMENT_TYPE_OP) {
	  ((sql_stmt_t*) stmt)->errMsg = SQL_STATEMENT_ERROR_INTERNAL;
	  YYABORT;
      }
      o->data.o.neg = !o->data.o.neg;
      yyval.bool_val = yyvsp[0].bool_val;
    ;
    break;}
case 73:
#line 480 "sql_yacc.y"
{ yyval.bool_val = yyvsp[-1].bool_val ;
    break;}
case 75:
#line 495 "sql_yacc.y"
{ sql_op_t o;
      o.arg1 = yyvsp[-2].scalar_val;
      o.opNum = yyvsp[-1].operator;
      o.arg2 = yyvsp[0].scalar_val;
      o.neg = 0;
      if ((yyval.bool_val = _AllocOp(stmt, &o)) == -1) {
	  YYABORT;
      }
#ifdef YYDEBUG
      printf("comparison_operator: %d %d %d -> %d\n", yyvsp[-2].scalar_val, yyvsp[-1].operator, yyvsp[0].scalar_val, yyval.bool_val);
#endif
    ;
    break;}
case 76:
#line 508 "sql_yacc.y"
{ sql_op_t o;
      o.arg1 = yyvsp[-2].scalar_val;
      o.opNum = SQL_STATEMENT_OPERATOR_IS;
      o.arg2 = yyvsp[0].null_val;
      o.neg = 0;
      if ((yyval.bool_val = _AllocOp(stmt, &o)) == -1) {
	  YYABORT;
      }
#ifdef YYDEBUG
      printf("IS operator: %d AND %d -> %d\n", yyvsp[-2].scalar_val, yyvsp[0].null_val, yyval.bool_val);
#endif
    ;
    break;}
case 77:
#line 521 "sql_yacc.y"
{ sql_op_t o;
      o.arg1 = yyvsp[-3].scalar_val;
      o.opNum = SQL_STATEMENT_OPERATOR_IS;
      o.arg2 = yyvsp[0].null_val;
      o.neg = 1;
      if ((yyval.bool_val = _AllocOp(stmt, &o)) == -1) {
	  YYABORT;
      }
#ifdef YYDEBUG
      printf("IS NOT operator: %d AND %d -> %d\n", yyvsp[-3].scalar_val, yyvsp[0].null_val, yyval.bool_val);
#endif
    ;
    break;}
case 80:
#line 564 "sql_yacc.y"
{ if ((yyval.scalar_val = _AllocInteger(stmt, yyvsp[0].int_val)) == -1) { YYABORT; } ;
    break;}
case 81:
#line 565 "sql_yacc.y"
{ if ((yyval.scalar_val = _AllocReal(stmt, yyvsp[0].real_val)) == -1) { YYABORT; } ;
    break;}
case 82:
#line 566 "sql_yacc.y"
{ if ((yyval.scalar_val = _AllocString(stmt, &yyvsp[0].string_val)) == -1) { YYABORT; } ;
    break;}
case 83:
#line 567 "sql_yacc.y"
{ yyval.scalar_val = yyvsp[0].null_val; ;
    break;}
case 84:
#line 568 "sql_yacc.y"
{ if ((yyval.scalar_val = _AllocParam(stmt, &yyvsp[0].param)) == -1) { YYABORT; } ;
    break;}
case 85:
#line 573 "sql_yacc.y"
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
      col.column = yyvsp[0].ident_val;
      if ((yyval.scalar_val = _AllocColumn(stmt, &col)) == -1) { YYABORT; }
    ;
    break;}
case 86:
#line 592 "sql_yacc.y"
{ sql_column_list_t column;
      column.column = yyvsp[0].scalar_val;
      if ((yyval.scalar_val = _AllocColumnList(stmt, &column)) == -1) {
	  YYABORT;
      }
    ;
    break;}
}
   /* the action file gets copied in in place of this dollarsign */
#line 542 "/usr/local/gnu/share/bison.simple"

  yyvsp -= yylen;
  yyssp -= yylen;
#ifdef YYLSP_NEEDED
  yylsp -= yylen;
#endif

#if YYDEBUG != 0
  if (yydebug)
    {
      short *ssp1 = yyss - 1;
      fprintf (stderr, "state stack now");
      while (ssp1 != yyssp)
	fprintf (stderr, " %d", *++ssp1);
      fprintf (stderr, "\n");
    }
#endif

  *++yyvsp = yyval;

#ifdef YYLSP_NEEDED
  yylsp++;
  if (yylen == 0)
    {
      yylsp->first_line = yylloc.first_line;
      yylsp->first_column = yylloc.first_column;
      yylsp->last_line = (yylsp-1)->last_line;
      yylsp->last_column = (yylsp-1)->last_column;
      yylsp->text = 0;
    }
  else
    {
      yylsp->last_line = (yylsp+yylen-1)->last_line;
      yylsp->last_column = (yylsp+yylen-1)->last_column;
    }
#endif

  /* Now "shift" the result of the reduction.
     Determine what state that goes to,
     based on the state we popped back to
     and the rule number reduced by.  */

  yyn = yyr1[yyn];

  yystate = yypgoto[yyn - YYNTBASE] + *yyssp;
  if (yystate >= 0 && yystate <= YYLAST && yycheck[yystate] == *yyssp)
    yystate = yytable[yystate];
  else
    yystate = yydefgoto[yyn - YYNTBASE];

  goto yynewstate;

yyerrlab:   /* here on detecting error */

  if (! yyerrstatus)
    /* If not already recovering from an error, report this error.  */
    {
      ++yynerrs;

#ifdef YYERROR_VERBOSE
      yyn = yypact[yystate];

      if (yyn > YYFLAG && yyn < YYLAST)
	{
	  int size = 0;
	  char *msg;
	  int x, count;

	  count = 0;
	  /* Start X at -yyn if nec to avoid negative indexes in yycheck.  */
	  for (x = (yyn < 0 ? -yyn : 0);
	       x < (sizeof(yytname) / sizeof(char *)); x++)
	    if (yycheck[x + yyn] == x)
	      size += strlen(yytname[x]) + 15, count++;
	  msg = (char *) malloc(size + 15);
	  if (msg != 0)
	    {
	      strcpy(msg, "parse error");

	      if (count < 5)
		{
		  count = 0;
		  for (x = (yyn < 0 ? -yyn : 0);
		       x < (sizeof(yytname) / sizeof(char *)); x++)
		    if (yycheck[x + yyn] == x)
		      {
			strcat(msg, count == 0 ? ", expecting `" : " or `");
			strcat(msg, yytname[x]);
			strcat(msg, "'");
			count++;
		      }
		}
	      yyerror(msg);
	      free(msg);
	    }
	  else
	    yyerror ("parse error; also virtual memory exceeded");
	}
      else
#endif /* YYERROR_VERBOSE */
	yyerror("parse error");
    }

  goto yyerrlab1;
yyerrlab1:   /* here on error raised explicitly by an action */

  if (yyerrstatus == 3)
    {
      /* if just tried and failed to reuse lookahead token after an error, discard it.  */

      /* return failure if at end of input */
      if (yychar == YYEOF)
	YYABORT;

#if YYDEBUG != 0
      if (yydebug)
	fprintf(stderr, "Discarding token %d (%s).\n", yychar, yytname[yychar1]);
#endif

      yychar = YYEMPTY;
    }

  /* Else will try to reuse lookahead token
     after shifting the error token.  */

  yyerrstatus = 3;		/* Each real token shifted decrements this */

  goto yyerrhandle;

yyerrdefault:  /* current state does not do anything special for the error token. */

#if 0
  /* This is wrong; only states that explicitly want error tokens
     should shift them.  */
  yyn = yydefact[yystate];  /* If its default is to accept any token, ok.  Otherwise pop it.*/
  if (yyn) goto yydefault;
#endif

yyerrpop:   /* pop the current state because it cannot handle the error token */

  if (yyssp == yyss) YYABORT;
  yyvsp--;
  yystate = *--yyssp;
#ifdef YYLSP_NEEDED
  yylsp--;
#endif

#if YYDEBUG != 0
  if (yydebug)
    {
      short *ssp1 = yyss - 1;
      fprintf (stderr, "Error: state stack now");
      while (ssp1 != yyssp)
	fprintf (stderr, " %d", *++ssp1);
      fprintf (stderr, "\n");
    }
#endif

yyerrhandle:

  yyn = yypact[yystate];
  if (yyn == YYFLAG)
    goto yyerrdefault;

  yyn += YYTERROR;
  if (yyn < 0 || yyn > YYLAST || yycheck[yyn] != YYTERROR)
    goto yyerrdefault;

  yyn = yytable[yyn];
  if (yyn < 0)
    {
      if (yyn == YYFLAG)
	goto yyerrpop;
      yyn = -yyn;
      goto yyreduce;
    }
  else if (yyn == 0)
    goto yyerrpop;

  if (yyn == YYFINAL)
    YYACCEPT;

#if YYDEBUG != 0
  if (yydebug)
    fprintf(stderr, "Shifting error token, ");
#endif

  *++yyvsp = yylval;
#ifdef YYLSP_NEEDED
  *++yylsp = yylloc;
#endif

  yystate = yyn;
  goto yynewstate;

 yyacceptlab:
  /* YYACCEPT comes here.  */
  if (yyfree_stacks)
    {
      free (yyss);
      free (yyvs);
#ifdef YYLSP_NEEDED
      free (yyls);
#endif
    }
  return 0;

 yyabortlab:
  /* YYABORT comes here.  */
  if (yyfree_stacks)
    {
      free (yyss);
      free (yyvs);
#ifdef YYLSP_NEEDED
      free (yyls);
#endif
    }
  return 1;
}
#line 599 "sql_yacc.y"



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
