#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include "debug.h"
#include "f_string.h"
#include "pp_cond.h"
#include "symbol.h"

#define IF_ZERO_COMMENT(x)	(TOK_IF == (x)->a.pp_if.type && TOK_ZERO == (x)->a.pp_if.expr.type)
#define IS_ELIF_ONE(x)	(TOK_NUMBER == (x)->a.pp_elif.expr.type && 0 != (x)->a.pp_elif.expr.a.con_val)
#define IS_ELIF_ZERO(x)	(TOK_ZERO == (x)->a.pp_elif.expr.type || (TOK_NUMBER == (x)->a.pp_elif.expr.type && 0 == (x)->a.pp_elif.expr.a.con_val))

static int is_if_zero(struct pp_cond * if_cond);
static int is_if_one(struct pp_cond * if_cond);

struct pp_cond *
make_pp_cond(struct f_string * str, struct f_string * code)
{
	struct pp_cond * pp_cond;

	DEBUG_ENTER();
	
	pp_cond = malloc(sizeof(*pp_cond));
	if (NULL == pp_cond)
		return DEBUG_FAIL(NULL);

	memset(pp_cond, 0, sizeof(*pp_cond));

	pp_cond->str = *str;
	pp_cond->code = *code;

	CLEAR_F_STRING(str);
	CLEAR_F_STRING(code);
	
	return DEBUG_RETURN(pp_cond);
}

struct f_string
flatten_if_elif_else(struct pp_cond * if_cond, struct pp_cond * elifs_cond, struct pp_cond * else_cond, struct f_string * endif_str)
{
	struct pp_cond * elif_cond = elifs_cond;
	int keep = 0;
	struct f_string out;

	DEBUG_ENTER();

	assert(NULL != if_cond);
	assert(NULL != endif_str);
	
	if (IF_ZERO_COMMENT(if_cond))
		keep = 1;

	if (is_if_one(if_cond)) {
		out = if_cond->code;
		CLEAR_F_STRING(&if_cond->code);
	} else if (is_if_zero(if_cond)
		   && ! keep)
	{
		while (NULL != elif_cond
		       && IS_ELIF_ZERO(elif_cond))
		{
			elif_cond = elif_cond->a.pp_elif.next;
		}

		if (NULL == elif_cond) {
			if (NULL != else_cond) {
				out = else_cond->code;
				CLEAR_F_STRING(&else_cond->code);
			} else
				out = empty_f_string();
		} else if (IS_ELIF_ONE(elif_cond)) {
			out = elif_cond->code;
			CLEAR_F_STRING(&elif_cond->code);
		} else {
			convert_elif_to_if_f_string(&elif_cond->str);
			out = combine3_f_string(&elif_cond->str, &elif_cond->a.pp_elif.expr.str, &elif_cond->code);
		
			/* NOTE: The current elif_cond is already processed */

			while (NULL != (elif_cond = elif_cond->a.pp_elif.next)
				&& ! IS_ELIF_ONE(elif_cond))
			{
				if (! IS_ELIF_ZERO(elif_cond)) {
					struct f_string temp;
					temp = combine3_f_string(&elif_cond->str, &elif_cond->a.pp_elif.expr.str, &elif_cond->code);
					out = combine_f_string(&out, &temp);
				}
			}

			if (NULL == elif_cond) {
				if (NULL != else_cond)
					out = combine3_f_string(&out, &else_cond->str, &else_cond->code);
				/* NOTE: out is already setup */
			} else {
				convert_elif_to_else_f_string(&elif_cond->str, &elif_cond->a.pp_elif.expr.str);
				out = combine3_f_string(&out, &elif_cond->str, &elif_cond->code);
			}

			out = combine_f_string(&out, endif_str);
		}
	} else {
		out = combine3_f_string(&if_cond->str, &if_cond->a.pp_if.expr.str, &if_cond->code);

		while (NULL != elif_cond
			&& ! IS_ELIF_ONE(elif_cond))
		{
			if (! IS_ELIF_ZERO(elif_cond)) {
				struct f_string temp;
				temp = combine3_f_string(&elif_cond->str, &elif_cond->a.pp_elif.expr.str, &elif_cond->code);
				out = combine_f_string(&out, &temp);
			}

			elif_cond = elif_cond->a.pp_elif.next;
		}
		
		if (NULL == elif_cond) {
			if (NULL != else_cond)
				out = combine3_f_string(&out, &else_cond->str, &else_cond->code);
			/* NOTE: out is already setup */
		} else {
			convert_elif_to_else_f_string(&elif_cond->str, &elif_cond->a.pp_elif.expr.str);
			out = combine3_f_string(&out, &elif_cond->str, &elif_cond->code);
		}

		out = combine_f_string(&out, endif_str);
	}

	release_f_string(endif_str);
	
	if (NULL != else_cond) {
		release_f_string(&else_cond->code);
		release_f_string(&else_cond->str);
		free(else_cond);
	}

	elif_cond = elifs_cond;

	/* TODO: Make this loop go backwards... */
	while (NULL != elif_cond) {
		struct pp_cond * next = elif_cond->a.pp_elif.next;

		release_f_string(&elif_cond->code);
		release_f_string(&elif_cond->a.pp_elif.expr.str);
		release_f_string(&elif_cond->str);
		free(elif_cond);

		elif_cond = next;
	}

	release_f_string(&if_cond->code);
	release_f_string(&if_cond->a.pp_if.expr.str);
	release_f_string(&if_cond->str);
	free(if_cond);

	return DEBUG_RETURN(out);
}

int
is_if_zero(struct pp_cond * if_cond)
{
	switch (if_cond->a.pp_if.type) {
	case TOK_IFDEF:
		return TOK_ID == if_cond->a.pp_if.expr.type
			&& is_undefined(if_cond->a.pp_if.expr.a.id_ref);
	case TOK_IFNDEF:
		return TOK_ID == if_cond->a.pp_if.expr.type
			&& is_defined(if_cond->a.pp_if.expr.a.id_ref);
	case TOK_IF:
		return TOK_ZERO == if_cond->a.pp_if.expr.type
			|| (TOK_NUMBER == if_cond->a.pp_if.expr.type
			    && 0 == if_cond->a.pp_if.expr.a.con_val);
	default:
		return 0;
	}
}

int
is_if_one(struct pp_cond * if_cond)
{
	switch (if_cond->a.pp_if.type) {
	case TOK_IFDEF:
		return TOK_ID == if_cond->a.pp_if.expr.type
			&& is_defined(if_cond->a.pp_if.expr.a.id_ref);
	case TOK_IFNDEF:
		return TOK_ID == if_cond->a.pp_if.expr.type
			&& is_undefined(if_cond->a.pp_if.expr.a.id_ref);
	case TOK_IF:
		return TOK_NUMBER == if_cond->a.pp_if.expr.type
			&& 0 != if_cond->a.pp_if.expr.a.con_val;
	default:
		return 0;
	}
}
