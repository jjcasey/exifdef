#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include "debug.h"
#include "f_string.h"

#define ELIF_MESSAGE	" /* was elif */ "
#define ELIF_TO_ELSE	"#else" ELIF_MESSAGE
#define ELIF_TO_IF	"#if" ELIF_MESSAGE

#define ARRAY_SIZE(x)	(sizeof(x)/sizeof((x)[ 0 ]))
#define CONST_STRLEN(x)	(ARRAY_SIZE(x) - 1)

/* TODO: Instead of using separate chunks of memory (and passing
 * around a 12 byte structure), the code could do two things: 1)
 * change the struct f_string to contain a pointer or index into a
 * managed memory pool.  2) Read the entire file into a buffer
 * (however the lex routines make a copy...) or as make_f_string is
 * called, allocate/grow a continous memory area.  As combine is
 * called, we use memcpy to move around the bytes.  This could work
 * since the rest of the code could care less how the memory is
 * utilized or laid out. */

struct f_string
make_f_string(const char * str, size_t length, size_t trailing_ws)
{
	struct f_string out = { 0 };

	DEBUG_ENTER();

	assert(NULL != str);
	assert(0 < length);
	assert(0 <= trailing_ws);
	assert(trailing_ws <= length);

	out.text = malloc(length);
	if (NULL == out.text) {
		DEBUG(DUNEXPECTED, "Unable to alloc %d byte text for \"%.*s\"\n", length, length, str);
		return DEBUG_FAIL(out);
	}
	
	out.length = length;
	memcpy(out.text, str, length);
	out.trailing_ws = trailing_ws;

	return DEBUG_RETURN(out);
}

struct f_string
empty_f_string(void)
{
	struct f_string out = { 0 };

	DEBUG_ENTER();
	
	out.text = malloc(1);
	if (NULL == out.text) {
		DEBUG(DUNEXPECTED, "Unable to alloc 1 byte text for an empty text\n");
		return DEBUG_FAIL(out);
	}

	out.text[ 0 ] = '\0';

	return DEBUG_RETURN(out);
}

void
release_f_string(struct f_string * x)
{
	if (NULL != x->text)
		free(x->text);

	CLEAR_F_STRING(x);
}

struct f_string
combine_f_string(struct f_string * x, struct f_string * y)
{
	struct f_string out;

	DEBUG_ENTER();

	assert(NULL != x);
	assert(NULL != y);
	assert(NULL != x->text);
	
	out = *x;

	CLEAR_F_STRING(x);
	
	if (0 < y->length) {
		char * text = realloc(out.text, out.length + y->length);

		if (NULL == text) {
			DEBUG(DUNEXPECTED, "Unable to realloc text to combine texts : \"%.*s\" & \"%.*s\"\n", out.length, out.text, y->length, y->text);
			release_f_string(y);
			return DEBUG_FAIL(out);
		}
		
		memcpy(text + out.length, y->text, y->length);
		out.length += y->length;
		out.text = text;
		if (y->trailing_ws < y->length)
			out.trailing_ws = y->trailing_ws;
		else
			out.trailing_ws += y->length;
	}

	release_f_string(y);
	
	return DEBUG_RETURN(out);
}

struct f_string
combine3_f_string(struct f_string * x, struct f_string * y, struct f_string * z)
{
	char * text;
	struct f_string out;

	DEBUG_ENTER();

	assert(NULL != x);
	assert(NULL != y);
	assert(NULL != z);
	assert(NULL != x->text);

	out = *x;

	CLEAR_F_STRING(x);
	
	if (0 >= y->length
		&& 0 >= z->length) 
		goto done;
	
	text = realloc(out.text, out.length + y->length + z->length);
	if (NULL == text) {
		DEBUG(DUNEXPECTED, "Unable to realloc text to combine texts : \"%.*s\", \"%.*s\" & \"%.*s\"\n", out.length, out.text, y->length, y->text, z->length, z->text);
		release_f_string(y);
		release_f_string(z);
		return DEBUG_FAIL(out);
	}

	out.text = text;
	
	if (0 < y->length) {
		memcpy(out.text + out.length, y->text, y->length);
		out.length += y->length;
		if (y->trailing_ws < y->length)
			out.trailing_ws = y->trailing_ws;
		else
			out.trailing_ws += y->length;
	}
	
	if (0 < z->length) {
		memcpy(out.text + out.length, z->text, z->length);
		out.length += z->length;
		if (z->trailing_ws < z->length)
			out.trailing_ws = z->trailing_ws;
		else
			out.trailing_ws += z->length;
	}	

done:
	release_f_string(y);
	release_f_string(z);
	
	return DEBUG_RETURN(out);
}

void
append_ws_f_string(struct f_string * x, struct f_string * y)
{
	DEBUG_ENTER();

	assert(NULL != x);
	assert(NULL != y);
	assert(0 <= y->trailing_ws);
	assert(y->trailing_ws <= y->length);
	
	if (0 < y->trailing_ws) {
		char * text = realloc(x->text, x->length + y->trailing_ws);

		if (NULL != text) {
			memcpy(text + x->length, y->text + (y->length - y->trailing_ws), y->trailing_ws);
			x->text = text;
			x->length += y->trailing_ws;
			x->trailing_ws += y->trailing_ws;
		} else {
			DEBUG(DUNEXPECTED, "Unable to realloc text \"%.*s\" to append white space\n", x->length, x->text);
		}
	}

	release_f_string(y);
	
	DEBUG_LEAVE();
}

void
convert_elif_to_if_f_string(struct f_string * elif)
{
	size_t pos_l;

	DEBUG_ENTER();

	assert(NULL != elif);
	assert(0 <= elif->trailing_ws);
	assert(elif->trailing_ws <= elif->length);

	pos_l = elif->length - elif->trailing_ws;
	
	while (0 < --pos_l)
		if ('l' == elif->text[ pos_l ]) {
			size_t pos_e = pos_l;

			while (0 < --pos_e)
				if ('e' == elif->text[ pos_e ]) {
					memmove(elif->text + pos_l, elif->text + pos_l + 1, elif->length - pos_l);
					memmove(elif->text + pos_e, elif->text + pos_e + 1, elif->length - pos_e);
					elif->length -= 2;
					goto finish;
				}
			break;
		}

	DEBUG(DUNEXPECTED, "Unable to find 'e' or 'l' in elif text : \"%.*s\"\n", elif->length, elif->text);
	
	release_f_string(elif);
	*elif = make_f_string(ELIF_TO_IF, CONST_STRLEN(ELIF_TO_IF), CONST_STRLEN(ELIF_MESSAGE));
finish:

	DEBUG_LEAVE();
}

void
convert_elif_to_else_f_string(struct f_string * elif, struct f_string * expr)
{
	size_t pos_f;

	DEBUG_ENTER();

	assert(NULL != elif);
	assert(0 <= elif->trailing_ws);
	assert(elif->trailing_ws <= elif->length);

	pos_f = elif->length - elif->trailing_ws;
	
	while (0 < --pos_f)
		if ('f' == elif->text[ pos_f ]) {
			size_t pos_i = pos_f;
			while (0 < --pos_i)
				if ('i' == elif->text[ pos_i ]) {
					elif->text[ pos_i ] = 's';
					elif->text[ pos_f ] = 'e';
					goto finish;
				}
			break;
		}

	DEBUG(DUNEXPECTED, "Unable to find 'i' or 'f' in elif text : \"%.*s\"\n", elif->length, elif->text);
	
	release_f_string(elif);
	*elif = make_f_string(ELIF_TO_ELSE, CONST_STRLEN(ELIF_TO_ELSE), CONST_STRLEN(ELIF_MESSAGE));
finish:
	append_ws_f_string(elif, expr);

	DEBUG_LEAVE();
}

void
truncate_truth_f_string(struct f_string * str, int truth)
{
	DEBUG_ENTER();
	
	assert(0 <= str->trailing_ws);
	assert(str->trailing_ws < str->length);

	memmove(str->text + 1, str->text + (str->length - str->trailing_ws), str->trailing_ws);
	str->text[ 0 ] = truth
		? '1'
		: '0';
	str->length = str->trailing_ws + 1;

	DEBUG_LEAVE();
}
