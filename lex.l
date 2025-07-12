%option 8bit
%option warn
%option nounput

%s pp_test pp comment_test comment comment_cpp char_const str_const code done

%{
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include "debug.h"
#include "f_string.h"
#include "grammar.tab.h"
#include "symbol.h"

static void build_ws(void);
static void build_str(void);
static void concat_ws(void);
static void concat_str(void);

int comment_caller;
int char_caller;
int str_caller;
%}

/* Declarations */

/* Trigraphs */
HASH	("#"|"??=")
CARET	("^"|"??'")
PIPE	("|"|"??!")
TILDE	("~"|"??-")
BSLASH	("\\"|"??/")

/* NOTE: These tokens aren't used... (error messages...) */
LSQUARE	("["|"??(")
RSQUARE	("]"|"??)")
LCURL	("{"|"??<")
RCURL	("}"|"??>")

EOL	("\r"?"\n")
SPLIT	({BSLASH}{EOL})

ZERO	"0"
OCT	[0-7]
NZERO	[1-9]	
DIGIT	[0-9]
HEX	[0-9A-Fa-f]
UTF16	({BSLASH}{SPLIT}*"u"({SPLIT}*{HEX}){4})
UTF32	({BSLASH}{SPLIT}*"U"({SPLIT}*{HEX}){8})
NDIGIT	([_A-Za-z]|UTF16|UTF32)
ID	({NDIGIT}({SPLIT}*({NDIGIT}|{DIGIT}))*)
WS	[ \t\v\f]

SIMP_ESC	({BSLASH}{SPLIT}*(['"?abfnrtv]|{BSLASH}))
OCT_ESC		({BSLASH}({SPLIT}*{OCT}){1,3})
HEX_ESC		({BSLASH}{SPLIT}*"x"({SPLIT}*{HEX})+)
ESC_SEQ		({UTF16}|{UTF32}|{SIMP_ESC}|{OCT_ESC}|{HEX_ESC})

UINT_SUF	[uU]
LONG_SUF	[lL]
LLONG_SUF	("l"{SPLIT}*"l"|"L"{SPLIT}*"L")
INT_SUF		({UINT_SUF}({SPLIT}*({LONG_SUF}|{LLONG_SUF}))?|({LONG_SUF}|{LLONG_SUF})({SPLIT}*{UINT_SUF})?)

QUEST	"?"
COLON	":"
OROR	({PIPE}{SPLIT}*{PIPE})
ANDAND	("&"{SPLIT}*"&")
OR	{PIPE}
XOR	{CARET}
AND	"&"
EQ	("="{SPLIT}*"=")
NEQ	("!"{SPLIT}*"=")
LE	("<"{SPLIT}*"=")
GE	(">"{SPLIT}*"=")
LSHIFT	("<"{SPLIT}*"<")
RSHIFT	(">"{SPLIT}*">")
LT	"<"
GT	">"
PLUS	"+"
MINUS	"-"
MULT	"*"
DIV	"/"
MOD	"%"
NOT	"!"
NEGATE	{TILDE}

LPAREN	"("
RPAREN	")"
COMMA	","

/* NOTE: Not valid in preprocessor expressions */
PASTE	({HASH}{SPLIT}*{HASH})

CHAR_OPEN	("'"|"L"{SPLIT}*"'")
CHAR		([^\\'\n]|{ESC_SEQ})
CHAR_CLOSE	"'"

STR_OPEN	("\""|"L"{SPLIT}*"\"")
STR		([^\\"\n]|{ESC_SEQ})	
STR_CLOSE	"\""

C_OPEN		("/"{SPLIT}*"*")
C_CLOSE		("*"{SPLIT}*"/")

C_OPEN_CPP	("/"{SPLIT}*"/")
C_CLOSE_CPP	{EOL}

%%
%{
	assert(pp_test != YY_START);

	if (INITIAL == YY_START)
		yylval.str = empty_f_string();
%}
	/* Rules */
<INITIAL>#	{ BEGIN(pp_test); concat_str(); }

<pp_test>{ID} {
		const int type = get_symbol(yytext, yyleng);

		concat_str();
		
		switch (type) {
		case TOK_IFDEF:
		case TOK_IFNDEF:
		case TOK_IF:
		case TOK_ELIF:
		case TOK_ELSE:
		case TOK_ENDIF:
			BEGIN(pp);
			return type;

		default:
			BEGIN(code);
			return TOK_CODE;
		}
	}

<INITIAL,pp_test>{WS}+	concat_ws(); 
<pp,code>{WS}+	{ build_ws(); return TOK_WS; }

<pp>{COLON}	{ build_str(); return TOK_COLON; }
<pp>{OROR}	{ build_str(); return TOK_OROR; }
<pp>{ANDAND}	{ build_str(); return TOK_ANDAND; }
<pp>{OR}	{ build_str(); return TOK_OR; }
<pp>{XOR}	{ build_str(); return TOK_XOR; }
<pp>{AND}	{ build_str(); return TOK_AND; }
<pp>{EQ}	{ build_str(); return TOK_EQ; }
<pp>{NEQ}	{ build_str(); return TOK_NEQ; }
<pp>{LE}	{ build_str(); return TOK_LE; }
<pp>{GE}	{ build_str(); return TOK_GE; }
<pp>{LSHIFT}	{ build_str(); return TOK_LSHIFT; }
<pp>{RSHIFT}	{ build_str(); return TOK_RSHIFT; }
<pp>{LT}	{ build_str(); return TOK_LT; }
<pp>{GT}	{ build_str(); return TOK_GT; }
<pp>{PLUS}	{ build_str(); return TOK_PLUS; }
<pp>{MINUS}	{ build_str(); return TOK_MINUS; }
<pp>{MULT}	{ build_str(); return TOK_MULT; }
<pp>{DIV}	{ build_str(); return TOK_DIV; }
<pp>{MOD}	{ build_str(); return TOK_MOD; }
<pp>{NOT}	{ build_str(); return TOK_NOT; }
<pp>{NEGATE}	{ build_str(); return TOK_NEGATE; }

<pp>{LPAREN}	{ build_str(); return TOK_LPAREN; }
<pp>{RPAREN}	{ build_str(); return TOK_RPAREN; }
<pp>{COMMA}	{ build_str(); return TOK_COMMA; }

<pp>{ZERO}({SPLIT}*{OCT})*{INT_SUF}? {
		yylval.con.str = make_f_string(yytext, yyleng, 0);
		yylval.con.val = get_long(yytext, yyleng, 8);
		return 0 != yylval.con.val ? TOK_NUMBER : TOK_ZERO;
	}
<pp>{NZERO}({SPLIT}*{DIGIT})*{INT_SUF}? {
		yylval.con.str = make_f_string(yytext, yyleng, 0);
		yylval.con.val = get_long(yytext, yyleng, 10);
		return 0 != yylval.con.val ? TOK_NUMBER : TOK_ZERO;
	}
<pp>{ZERO}{SPLIT}*x({SPLIT}*{HEX})+{INT_SUF}? {
		yylval.con.str = make_f_string(yytext, yyleng, 0);
		yylval.con.val = get_long(yytext, yyleng, 16);
		return 0 != yylval.con.val ? TOK_NUMBER : TOK_ZERO;
	}
<pp>{ID} {
		if (TOK_DEFINED == get_symbol(yytext, yyleng)) {
			build_str();
			return TOK_DEFINED;
		}

		yylval.id.str = make_f_string(yytext, yyleng, 0);
		yylval.id.ref = get_symref(yytext, yyleng, SYMBOL__UNKNOWN);
		return TOK_ID;
	}
<INITIAL,pp_test>{SPLIT}+	concat_ws();
<pp,code>{SPLIT}+ { build_ws(); return TOK_SPLIT; }

<INITIAL,pp_test>{EOL} { BEGIN(code); yyless(0); return TOK_CODE; }
<pp>{EOL}	{ BEGIN(INITIAL); build_ws(); return TOK_EOL; }
<code>{EOL}+	{ BEGIN(INITIAL); build_ws(); return TOK_EOL; }

<INITIAL,pp_test><<EOF>> { BEGIN(code); return TOK_CODE; }
<pp,code><<EOF>> { BEGIN(done); yylval.str = empty_f_string(); return TOK_EOF; }

	/* Character Constants */
<INITIAL,pp_test>{CHAR_OPEN} { BEGIN(code); yyless(0); return TOK_CODE; }
<pp,code>{CHAR_OPEN} {
		char_caller = YY_START;
		if (INITIAL == char_caller)
			char_caller = code;
		BEGIN(char_const);
		build_str();
		return TOK_CHAR_OPEN;
	}
<char_const>{SPLIT}+ { build_str(); return TOK_CHAR_TEXT; }
<char_const>{CHAR}+ { build_str(); return TOK_CHAR_TEXT; }
<char_const>{CHAR_CLOSE} { BEGIN(char_caller); return TOK_CHAR_CLOSE; }

	/* String Constants */
<INITIAL,pp_test>{STR_OPEN} { BEGIN(code); yyless(0); return TOK_CODE; }
<pp,code>{STR_OPEN} {
		str_caller = YY_START;
		if (INITIAL == str_caller)
			str_caller = code;
		BEGIN(str_const);
		build_str();
		return TOK_STR_OPEN;
	}
<str_const>{STR}+ { build_str(); return TOK_STR_TEXT; }
<str_const>{STR_CLOSE} { BEGIN(str_caller); return TOK_STR_CLOSE; }

	/* C Comments */
<INITIAL,pp_test>{C_OPEN} {
		comment_caller = YY_START;
		BEGIN(comment_test);
		concat_ws();
	}
<pp,code>{C_OPEN} {
		comment_caller = YY_START;
		BEGIN(comment);
		build_ws();
		return TOK_C_OPEN; 
	}
<comment_test>{C_CLOSE}	{ BEGIN(comment_caller); concat_ws(); }
<comment>{C_CLOSE}	{ BEGIN(comment_caller); build_ws(); return TOK_C_CLOSE; }
	/* FIXME: Ensure that this works */
<comment_test>[^*]+		concat_ws();
<comment_test>"*"+[^*/\\]*	concat_ws();
<comment>[^*]+		{ build_ws(); return TOK_C_TEXT; }
<comment>"*"+[^*/\\]*	{ build_ws(); return TOK_C_TEXT; }

	/* C++ Comments */
<INITIAL,pp_test>{C_OPEN_CPP} { BEGIN(code); yyless(0); return TOK_CODE; }
<pp,code>{C_OPEN_CPP} {
		comment_caller = YY_START;
		BEGIN(comment_cpp);
		build_ws();
		return TOK_C_OPEN_CPP;
	}
<comment_cpp>{SPLIT}+		{ build_ws(); return TOK_C_TEXT; }
<comment_cpp>{C_CLOSE_CPP}	{ BEGIN(comment_caller); yyless(0); return TOK_C_CLOSE_CPP; }
<comment_cpp><<EOF>>		{ BEGIN(comment_caller); return TOK_C_CLOSE_CPP; }
<comment_cpp>[^\r\n]*[^\r\n\\]	{ build_ws(); return TOK_C_TEXT; }

<code>[^\r\n]*[^\r\n\\]	{ build_str(); return TOK_CODE; }
<code>.		{ build_str(); return TOK_CODE; }

	/* NOTE: Anything not already considered bumps us to the code state. */
<INITIAL,pp_test>.	{ BEGIN(code); yyless(0); return TOK_CODE; }

	/* NOTE: Last so as to not pre-empt trigraphs... */
<pp>{QUEST}	{ build_str(); return TOK_QUEST; }
%%
	/* User code... */

void
build_ws(void)
{
	DEBUG_ENTER();

	yylval.str = make_f_string(yytext, yyleng, yyleng);

	DEBUG_LEAVE();
}

void
build_str(void)
{
	DEBUG_ENTER();

	yylval.str = make_f_string(yytext, yyleng, 0);

	DEBUG_LEAVE();
}

void
concat_ws(void)
{
	struct f_string temp;
	
	DEBUG_ENTER();

	temp = make_f_string(yytext, yyleng, yyleng);
	yylval.str = combine_f_string(&yylval.str, &temp);

	DEBUG_LEAVE();
}

void
concat_str(void)
{
	struct f_string temp;
	
	DEBUG_ENTER();

	temp = make_f_string(yytext, yyleng, 0);
	yylval.str = combine_f_string(&yylval.str, &temp);

	DEBUG_LEAVE();
}
