%defines
%{
#include <stddef.h>
#include "debug.h"
#include "f_string.h"
#include "options.h"
#include "pp_cond.h"
#include "symbol.h"

#ifndef NDEBUG
#define YYDEBUG 1
#endif

#define BUILD_IF_COND(x,y,z,exp,eol,code)			\
do {								\
	(y) = combine_f_string(&(y), &(z));			\
	(x) = make_pp_cond(&(y), &(code));			\
	(exp).str = combine_f_string(&(exp).str, &(eol));	\
	(x)->a.pp_if.expr = (exp);				\
} while (0)
#define BUILD_IF(x,t,y,z,exp,eol,code)		\
do {						\
	BUILD_IF_COND(x,y,z,exp,eol,code);	\
	(x)->a.pp_if.type = (t);		\
} while (0)
#define BUILD_2OP(x,t,op,a,b)					\
do {								\
	(x).type = (t);						\
	(x).str = combine3_f_string(&(a).str, &(op), &(b).str);	\
} while (0)
#define BUILD_1OP(x,t,op,b)				\
do {							\
	(x).type = (t);					\
	(x).str = combine_f_string(&(op), &(b).str);	\
} while (0)
#define BUILD_TRUTH(x,t,s)			\
do {						\
	(x).type = TOK_NUMBER;			\
	(x).str = (s);				\
	truncate_truth_f_string(&(x).str, (t));	\
	(x).a.con_val = (t);			\
} while (0)
#define BUILD_NUMBER(x,c)			\
do {						\
	(x).type = TOK_NUMBER;			\
	(x).str = (c).str;			\
	(x).a.con_val = (c).val;		\
} while (0)
#define BUILD_ZERO(x,c)				\
do {						\
	(x).type = TOK_ZERO;			\
	(x).str = (c).str;			\
	(x).a.con_val = 0;			\
} while (0)
#define BUILD_ID(x,i)				\
do {						\
	(x).type = TOK_ID;			\
	(x).str = (i).str;			\
	(x).a.id_ref = (i).ref;			\
} while (0)

int yylex(void);
void yyerror(const char * s);
%}
%union {
	struct f_string {
		size_t length;
		char * text;
		size_t trailing_ws;
	} str;
	struct constant {
		struct f_string str;
		int long val;
	} con;
	struct id {
		struct f_string str;
		int ref;
	} id;
	struct expr {
		int type;
		struct f_string str;
		union {
			int long con_val;
			int id_ref;
		} a;
	} expr;
	struct pp_cond {
		struct f_string str;
		struct f_string code;
		union {
			struct {
				struct expr expr;
				int type;
			} pp_if;
			struct {
				struct expr expr;
				struct pp_cond * next;
			} pp_elif;
			/* NOTE: pp_else doesn't need anything else */
		} a;
	} * pp_cond;

	struct node {
		struct f_string str;
		int type;
		union nodevalue {
			int long con_val;
			int id_ref;
			struct f_string str;
		} a;
		struct node * up, * left, * right;
	} * node;
}
%token <con> TOK_NUMBER TOK_ZERO

%token <str> TOK_IFDEF TOK_IFNDEF TOK_IF TOK_ELSE TOK_ELIF TOK_ENDIF
%token <str> TOK_CODE

%token <id> TOK_ID

%token <str> TOK_WS TOK_EOL TOK_SPLIT TOK_EOF

%token <str> TOK_C_OPEN TOK_C_TEXT TOK_C_CLOSE
%token <str> TOK_C_OPEN_CPP TOK_C_CLOSE_CPP
%token <str> TOK_CHAR_OPEN TOK_CHAR_TEXT TOK_CHAR_CLOSE
%token <str> TOK_STR_OPEN TOK_STR_TEXT TOK_STR_CLOSE

%token <str> TOK_COMMA
%token <str> TOK_QUEST
%token <str> TOK_COLON
%token <str> TOK_OROR
%token <str> TOK_ANDAND
%token <str> TOK_OR
%token <str> TOK_XOR
%token <str> TOK_AND
%token <str> TOK_EQ TOK_NEQ
%token <str> TOK_LE TOK_GE TOK_LT TOK_GT
%token <str> TOK_LSHIFT TOK_RSHIFT
%token <str> TOK_PLUS TOK_MINUS
%token <str> TOK_MULT TOK_DIV TOK_MOD
%token <str> TOK_NOT TOK_NEGATE
%token <str> TOK_DEFINED
%token <str> TOK_LPAREN TOK_RPAREN

%type <str> c_source c_source1 c_source2 code_line code_line1 code_line2 code eol ws ws1 space space1 ws_nospace comment comment_cpp comment_text char_const char_const1 str_const str_const1
%type <pp_cond> pp_if pp_elifs pp_elif pp_else
%type <str> pp_endif
%type <str> ifdef ifndef if elif else endif
%type <expr> id expr oror_expr andand_expr or_expr xor_expr and_expr equality_expr relational_expr shift_expr additive_expr multi_expr unary_expr primary_expr constant
%type <str> quest colon oror andand or xor and equality inequality le ge lt gt lshift rshift plus minus mult div mod not negate parm parm1 comma defined lparen rparen
%%

c_file	: c_source { DEBUG(DPRINT, "%.*s", $1.length, $1.text); } ;

c_source	: c_source1 | /* empty */ { $$=empty_f_string(); } ;
c_source1	: c_source2
		| c_source1 c_source2 { $$=combine_f_string(&$1, &$2); }
		;

c_source2	: code_line eol { $$=combine_f_string(&$1, &$2); }
	 	| pp_if pp_endif { $$=flatten_if_elif_else($1, NULL, NULL, &$2); }
	 	| pp_if pp_else pp_endif { $$=flatten_if_elif_else($1, NULL, $2, &$3); }
		| pp_if pp_elifs pp_endif { $$=flatten_if_elif_else($1, $2, NULL, &$3); }
		| pp_if pp_elifs pp_else pp_endif { $$=flatten_if_elif_else($1, $2, $3, &$4); }
		;

code_line	: code_line1 | /* empty */ { $$=empty_f_string(); } ;
code_line1	: code_line2
		| code_line1 code_line2 { $$=combine_f_string(&$1, &$2); }
		;

code_line2	: code
		| char_const
		| str_const
		;

code	: TOK_CODE | TOK_CODE ws { $$=combine_f_string(&$1, &$2); } ;

char_const	: char_const1 | char_const1 ws { $$=combine_f_string(&$1, &$2); } ;
char_const1	: TOK_CHAR_OPEN TOK_CHAR_CLOSE { $$=combine_f_string(&$1, &$2); }
		| TOK_CHAR_OPEN TOK_CHAR_TEXT TOK_CHAR_CLOSE { $$=combine3_f_string(&$1, &$2, &$3); }
		;

str_const	: str_const1 | str_const1 ws { $$=combine_f_string(&$1, &$2); } ;
str_const1	: TOK_STR_OPEN TOK_STR_CLOSE { $$=combine_f_string(&$1, &$2); }
		| TOK_STR_OPEN TOK_STR_TEXT TOK_STR_CLOSE { $$=combine3_f_string(&$1, &$2, &$3); }
		;

pp_if	: ifdef space id eol c_source { BUILD_IF($$, TOK_IFDEF, $1, $2, $3, $4, $5); }
	| ifndef space id eol c_source { BUILD_IF($$, TOK_IFNDEF, $1, $2, $3, $4, $5); }
	| if space expr eol c_source { BUILD_IF($$, TOK_IF, $1, $2, $3, $4, $5); }
	;

pp_elifs	: pp_elif
		| pp_elifs pp_elif {
			struct pp_cond * pp_elif = $1;

			while (NULL != pp_elif->a.pp_elif.next)
				pp_elif = pp_elif->a.pp_elif.next;

			pp_elif->a.pp_elif.next = $2;
			$$ = $1;
		}
		;

pp_elif	: elif space expr eol c_source { BUILD_IF_COND($$, $1, $2, $3, $4, $5); } ;
pp_else	: else eol c_source { $1 = combine_f_string(&$1, &$2); $$ = make_pp_cond(&$1, &$3); } ;
pp_endif: endif eol { $$ = combine_f_string(&$1, &$2); } ;

expr	: oror_expr
	| oror_expr quest expr colon expr {
		if (TOK_NUMBER == $1.type
			&& 0 != $1.a.con_val)
		{
			$$ = $3;
			append_ws_f_string(&$$.str, &$5.str);
			release_f_string(&$4);
			release_f_string(&$2);
			release_f_string(&$1.str);
		} else if ((TOK_NUMBER == $1.type
				&& 0 == $1.a.con_val)
				|| TOK_ZERO == $1.type)
		{
			$$ = $5;
			release_f_string(&$4);
			release_f_string(&$3.str);
			release_f_string(&$2);
			release_f_string(&$1.str);
		} else {
			$3.str = combine3_f_string(&$3.str, &$4, &$5.str);
			BUILD_2OP($$, TOK_QUEST, $2, $1, $3);
		}
	}
	;

oror_expr	: andand_expr
		| oror_expr oror andand_expr {
			if ((TOK_NUMBER == $1.type
			     && 0 != $1.a.con_val)
			    || (TOK_NUMBER == $3.type
				&& 0 != $3.a.con_val))
			{
				BUILD_TRUTH($$, 1, $3.str);
				release_f_string(&$2);
				release_f_string(&$1.str);
			} else if (TOK_NUMBER == $1.type
				   || TOK_ZERO == $1.type)
			{
				if (TOK_NUMBER == $3.type
				    || TOK_ZERO == $3.type)
					BUILD_TRUTH($$, 0, $3.str);
				else
					$$ = $3;
				release_f_string(&$2);
				release_f_string(&$1.str);
			} else if (TOK_NUMBER == $3.type
				   || TOK_ZERO == $3.type)
			{
				$$ = $1;
				append_ws_f_string(&$$.str, &$3.str);
				release_f_string(&$2);
			} else
				BUILD_2OP($$, TOK_OROR, $2, $1, $3);
		}
		;

andand_expr	: or_expr
		| andand_expr andand or_expr {
			if ((TOK_NUMBER == $1.type
			     && 0 == $1.a.con_val)
			    || TOK_ZERO == $1.type
			    || (TOK_NUMBER == $3.type
				&& 0 == $3.a.con_val)
			    || TOK_ZERO == $3.type)
			{
				BUILD_TRUTH($$, 0, $3.str);
				release_f_string(&$2);
				release_f_string(&$1.str);
			} else if (TOK_NUMBER == $1.type) {
				if (TOK_NUMBER == $3.type)
					BUILD_TRUTH($$, 1, $3.str);
				else
					$$ = $3;
				release_f_string(&$2);
				release_f_string(&$1.str);
			} else if (TOK_NUMBER == $3.type) {
				$$ = $1;
				append_ws_f_string(&$$.str, &$3.str);
				release_f_string(&$2);
			} else
				BUILD_2OP($$, TOK_ANDAND, $2, $1, $3);
		}
		;

or_expr	: xor_expr
	| or_expr or xor_expr { BUILD_2OP($$, TOK_OR, $2, $1, $3); }
	;

xor_expr	: and_expr
		| xor_expr xor and_expr { BUILD_2OP($$, TOK_XOR, $2, $1, $3); }
		;

and_expr	: equality_expr
		| and_expr and equality_expr { BUILD_2OP($$, TOK_AND, $2, $1, $3); }
		;

equality_expr	: relational_expr
		| equality_expr equality relational_expr {
			if ((TOK_NUMBER == $1.type
			     || TOK_ZERO == $1.type)
			    && (TOK_NUMBER == $3.type
				|| TOK_ZERO == $3.type))
			{
				BUILD_TRUTH($$, $1.a.con_val == $3.a.con_val, $3.str);
				release_f_string(&$2);
				release_f_string(&$1.str);
			} else
				BUILD_2OP($$, TOK_EQ, $2, $1, $3);
		}
		| equality_expr inequality relational_expr {
			if ((TOK_NUMBER == $1.type
			     || TOK_ZERO == $1.type)
			    && (TOK_NUMBER == $3.type
				|| TOK_ZERO == $3.type))
			{
				BUILD_TRUTH($$, $1.a.con_val != $3.a.con_val, $3.str);
				release_f_string(&$2);
				release_f_string(&$1.str);
			} else
				BUILD_2OP($$, TOK_NEQ, $2, $1, $3);
		}
		;

relational_expr	: shift_expr
		| relational_expr le shift_expr {
			if ((TOK_NUMBER == $1.type
			     || TOK_ZERO == $1.type)
			    && (TOK_NUMBER == $3.type
				|| TOK_ZERO == $3.type))
			{
				BUILD_TRUTH($$, $1.a.con_val <= $3.a.con_val, $3.str);
				release_f_string(&$2);
				release_f_string(&$1.str);
			} else
				BUILD_2OP($$, TOK_LE, $2, $1, $3);
		}
		| relational_expr ge shift_expr {
			if ((TOK_NUMBER == $1.type
			     || TOK_ZERO == $1.type)
			    && (TOK_NUMBER == $3.type
				|| TOK_ZERO == $3.type))
			{
				BUILD_TRUTH($$, $1.a.con_val >= $3.a.con_val, $3.str);
				release_f_string(&$2);
				release_f_string(&$1.str);
			} else
				BUILD_2OP($$, TOK_GE, $2, $1, $3);
		}
		| relational_expr lt shift_expr {
			if ((TOK_NUMBER == $1.type
			     || TOK_ZERO == $1.type)
			    && (TOK_NUMBER == $3.type
				|| TOK_ZERO == $3.type))
			{
				BUILD_TRUTH($$, $1.a.con_val < $3.a.con_val, $3.str);
				release_f_string(&$2);
				release_f_string(&$1.str);
			} else
				BUILD_2OP($$, TOK_LT, $2, $1, $3);
		}
		| relational_expr gt shift_expr {
			if ((TOK_NUMBER == $1.type
			     || TOK_ZERO == $1.type)
			    && (TOK_NUMBER == $3.type
				|| TOK_ZERO == $3.type))
			{
				BUILD_TRUTH($$, $1.a.con_val > $3.a.con_val, $3.str);
				release_f_string(&$2);
				release_f_string(&$1.str);
			} else
				BUILD_2OP($$, TOK_GT, $2, $1, $3);
		}
		;

shift_expr	: additive_expr
		| shift_expr lshift additive_expr { BUILD_2OP($$, TOK_LSHIFT, $2, $1, $3); }
		| shift_expr rshift additive_expr { BUILD_2OP($$, TOK_RSHIFT, $2, $1, $3); }
		;

additive_expr	: multi_expr
		| additive_expr plus multi_expr { BUILD_2OP($$, TOK_PLUS, $2, $1, $3); }
		| additive_expr minus multi_expr { BUILD_2OP($$, TOK_MINUS, $2, $1, $3); }
		;

multi_expr	: unary_expr
		| multi_expr mult unary_expr { BUILD_2OP($$, TOK_MULT, $2, $1, $3); }
		| multi_expr div unary_expr { BUILD_2OP($$, TOK_DIV, $2, $1, $3); }
		| multi_expr mod unary_expr { BUILD_2OP($$, TOK_MOD, $2, $1, $3); }
		;

unary_expr	: primary_expr
		| not unary_expr {
			if (TOK_NUMBER == $2.type
			    || TOK_ZERO == $2.type)
			{
				BUILD_TRUTH($$, ! $2.a.con_val, $2.str);
				release_f_string(&$1);
			} else
				BUILD_1OP($$, TOK_NOT, $1, $2);
		}
		| plus unary_expr { BUILD_1OP($$, TOK_PLUS, $1, $2); }
		| minus unary_expr { BUILD_1OP($$, TOK_MINUS, $1, $2); }
		| negate unary_expr { BUILD_1OP($$, TOK_NEGATE, $1, $2); }
		;

primary_expr	: lparen expr rparen {
			if (TOK_NUMBER == $2.type
			    || TOK_ZERO == $2.type
			    || TOK_RPAREN == $2.type
			    || TOK_LPAREN == $2.type
			    || TOK_DEFINED == $2.type)
			{
				$$ = $2;
				append_ws_f_string(&$$.str, &$3);
				release_f_string(&$1);
			} else {
				$$.type = TOK_RPAREN;
				$$.str = combine3_f_string(&$1, &$2.str, &$3);
			}
		}
		| defined id {
			if (is_defined($2.a.id_ref)) {
				BUILD_TRUTH($$, 1, $2.str);
				release_f_string(&$1);
			} else if (is_undefined($2.a.id_ref)) {
				BUILD_TRUTH($$, 0, $2.str);
				release_f_string(&$1);
			} else
				BUILD_1OP($$, TOK_DEFINED, $1, $2);
		}
		| defined lparen id rparen {
			if (is_defined($3.a.id_ref)) {
				BUILD_TRUTH($$, 1, $4);
				release_f_string(&$3.str);
				release_f_string(&$2);
				release_f_string(&$1);
			} else if (is_undefined($3.a.id_ref)) {
				BUILD_TRUTH($$, 0, $4);
				release_f_string(&$3.str);
				release_f_string(&$2);
				release_f_string(&$1);
			} else {
				$1 = combine_f_string(&$1, &$2);
				$3.str = combine_f_string(&$3.str, &$4);
				BUILD_1OP($$, TOK_DEFINED, $1, $3);
			}
		}
		| id lparen parm rparen {
			$2 = combine3_f_string(&$2, &$3, &$4);
			$$.type = TOK_LPAREN;
			$$.str = combine_f_string(&$1.str, &$2);
		}
		| id {
			if (is_undefined($1.a.id_ref))
				BUILD_TRUTH($$, 0, $1.str);
			else
				$$ = $1;
		}
		| constant
		| char_const { 
			$$.type = TOK_CHAR_TEXT;
			$$.str = $1;
		}
		;

id	: TOK_ID { BUILD_ID($$, $1); }
	| TOK_ID ws {
		$1.str = combine_f_string(&$1.str, &$2);
		BUILD_ID($$, $1);
	}
	;

parm	: parm1 | /* empty */ { $$ = empty_f_string(); } ;
parm1	: expr { $$ = $1.str; }
	| parm1 comma expr { $$ = combine3_f_string(&$1, &$2, &$3.str); }
	;

constant	: TOK_NUMBER { BUILD_NUMBER($$, $1); }
		| TOK_NUMBER ws {
			$1.str = combine_f_string(&$1.str, &$2);
			BUILD_NUMBER($$, $1);
		}
		| TOK_ZERO { BUILD_ZERO($$, $1); }
		| TOK_ZERO ws {
			$1.str = combine_f_string(&$1.str, &$2);
			BUILD_ZERO($$, $1);
		}
		;

ifdef	: TOK_IFDEF	| TOK_IFDEF ws_nospace { $$=combine_f_string(&$1, &$2); } ;
ifndef	: TOK_IFNDEF	| TOK_IFNDEF ws_nospace { $$=combine_f_string(&$1, &$2); } ;
if	: TOK_IF	| TOK_IF ws_nospace { $$=combine_f_string(&$1, &$2); } ;
elif	: TOK_ELIF	| TOK_ELIF ws_nospace { $$=combine_f_string(&$1, &$2); } ;
else	: TOK_ELSE	| TOK_ELSE ws { $$=combine_f_string(&$1, &$2); } ;
endif	: TOK_ENDIF	| TOK_ENDIF ws { $$=combine_f_string(&$1, &$2); } ;

quest	: TOK_QUEST	| TOK_QUEST ws { $$=combine_f_string(&$1, &$2); } ;
colon	: TOK_COLON	| TOK_COLON ws { $$=combine_f_string(&$1, &$2); } ;
oror	: TOK_OROR	| TOK_OROR ws { $$=combine_f_string(&$1, &$2); } ;
andand	: TOK_ANDAND	| TOK_ANDAND ws { $$=combine_f_string(&$1, &$2); } ;
or	: TOK_OR	| TOK_OR ws { $$=combine_f_string(&$1, &$2); } ;
xor	: TOK_XOR	| TOK_XOR ws { $$=combine_f_string(&$1, &$2); } ;
and	: TOK_AND	| TOK_AND ws { $$=combine_f_string(&$1, &$2); } ;
equality	: TOK_EQ | TOK_EQ ws { $$=combine_f_string(&$1, &$2); } ;
inequality	: TOK_NEQ | TOK_NEQ ws { $$=combine_f_string(&$1, &$2); } ;
le	: TOK_LE	| TOK_LE ws { $$=combine_f_string(&$1, &$2); } ;
ge	: TOK_GE	| TOK_GE ws { $$=combine_f_string(&$1, &$2); } ;
lt	: TOK_LT	| TOK_LT ws { $$=combine_f_string(&$1, &$2); } ;
gt	: TOK_GT	| TOK_GT ws { $$=combine_f_string(&$1, &$2); } ;
lshift	: TOK_LSHIFT	| TOK_LSHIFT ws { $$=combine_f_string(&$1, &$2); } ;
rshift	: TOK_RSHIFT	| TOK_RSHIFT ws { $$=combine_f_string(&$1, &$2); } ;
mult	: TOK_MULT	| TOK_MULT ws { $$=combine_f_string(&$1, &$2); } ;
div	: TOK_DIV	| TOK_DIV ws { $$=combine_f_string(&$1, &$2); } ;
mod	: TOK_MOD	| TOK_MOD ws { $$=combine_f_string(&$1, &$2); } ;
not	: TOK_NOT	| TOK_NOT ws { $$=combine_f_string(&$1, &$2); } ;
plus	: TOK_PLUS	| TOK_PLUS ws { $$=combine_f_string(&$1, &$2); } ;
minus	: TOK_MINUS	| TOK_MINUS ws { $$=combine_f_string(&$1, &$2); } ;
negate	: TOK_NEGATE	| TOK_NEGATE ws { $$=combine_f_string(&$1, &$2); } ;
lparen	: TOK_LPAREN	| TOK_LPAREN ws { $$=combine_f_string(&$1, &$2); } ;
rparen	: TOK_RPAREN	| TOK_RPAREN ws { $$=combine_f_string(&$1, &$2); } ;
defined	: TOK_DEFINED	| TOK_DEFINED ws { $$=combine_f_string(&$1, &$2); } ;
comma	: TOK_COMMA	| TOK_COMMA ws { $$=combine_f_string(&$1, &$2); } ;

eol	: TOK_EOL
	| TOK_EOF
	| comment_cpp TOK_EOL { $$=combine_f_string(&$1, &$2); }
	| comment_cpp TOK_EOF { $$=combine_f_string(&$1, &$2); }
	;

ws	: ws1 | ws ws1 { $$=combine_f_string(&$1, &$2); } ;
ws1	: TOK_WS
	| TOK_SPLIT
	| comment
	;

space	: space1 | space1 ws { $$=combine_f_string(&$1, &$2); } ;
space1	: TOK_WS
	| comment
	;

ws_nospace	: TOK_SPLIT
		| ws_nospace TOK_SPLIT { $$=combine_f_string(&$1, &$2); }
		;

comment	: TOK_C_OPEN TOK_C_CLOSE { $$=combine_f_string(&$1, &$2); }
	| TOK_C_OPEN comment_text TOK_C_CLOSE { $$=combine3_f_string(&$1, &$2, &$3); }
	;

comment_cpp	: TOK_C_OPEN_CPP TOK_C_CLOSE_CPP { $$ = $1; }
		| TOK_C_OPEN_CPP comment_text TOK_C_CLOSE_CPP { $$=combine_f_string(&$1, &$2); }
		;

comment_text	: TOK_C_TEXT
		| comment_text TOK_C_TEXT { $$=combine_f_string(&$1, &$2); }
		;
%%
#include "symbol.h"

int
main(int argc, char * const argv[])
{
	int ret;

	DEBUG_ENTER();

	parse_options(argc, argv);

#if YYDEBUG
	if (~0 == debug)
		yydebug = 1;
#endif

	ret = yyparse();

	return DEBUG_RETURN(ret);
}

void
yyerror(const char * s)
{
	debug_print(DUNEXPECTED, "%s\n", s);
}
