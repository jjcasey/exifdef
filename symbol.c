#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "debug.h"
#include "grammar.tab.h"
#include "symbol.h"

#define ARRAY_SIZE(x)	(sizeof(x)/sizeof((x)[ 0 ]))
#define CONST_STRLEN(x)	(ARRAY_SIZE(x) - 1)
#define SYM_ENTRY(x,n)	{ CONST_STRLEN(x), (x), (n) | SYMBOL__PREDEFINED }
#define SPLIT		"\\\n"
#define SPLIT_DOS	"\\\r\n"
#define SPLIT_TRI	"\?\?/\n"
#define SPLIT_TRI_DOS	"\?\?/\r\n"

struct symbol {
	size_t length;
	const char * str;
	int ref;
} static const predefined[] = {
	SYM_ENTRY("if", TOK_IF),
	SYM_ENTRY("elif", TOK_ELIF),
	SYM_ENTRY("else", TOK_ELSE),
	SYM_ENTRY("endif", TOK_ENDIF),
	SYM_ENTRY("ifdef", TOK_IFDEF),
	SYM_ENTRY("ifndef", TOK_IFNDEF),
	SYM_ENTRY("defined", TOK_DEFINED)
};

struct symbol_table {
	const struct symbol_table * next;
	struct symbol entry;
};
static const struct symbol_table sym_defined = { NULL, SYM_ENTRY("defined", TOK_DEFINED) };
static const struct symbol_table sym_ifndef = { &sym_defined, SYM_ENTRY("ifndef", TOK_IFNDEF) };
static const struct symbol_table sym_ifdef = { &sym_ifndef, SYM_ENTRY("ifdef", TOK_IFDEF) };
static const struct symbol_table sym_endif = { &sym_ifdef, SYM_ENTRY("endif", TOK_ENDIF) };
static const struct symbol_table sym_else = { &sym_endif, SYM_ENTRY("else", TOK_ELSE) };
static const struct symbol_table sym_elif = { &sym_else, SYM_ENTRY("elif", TOK_ELIF) };
static const struct symbol_table sym_if = { &sym_elif, SYM_ENTRY("if", TOK_IF) };

static const struct symbol_table * table = &sym_if;
static int last_unknown = SYMBOL__UNKNOWN;
static int last_defined = SYMBOL__DEFINED;
static int last_undefined = SYMBOL__UNDEFINED;

static char * flatten(const char * str, size_t * const plength);

int
get_symbol(const char * str, size_t length)
{
	char * flat;
	int i;

	DEBUG_ENTER();

	flat = flatten(str, &length);
	if (NULL == flat)
		return DEBUG_FAIL(0);

	for (i = 0; i < ARRAY_SIZE(predefined); i++)
		if (predefined[ i ].length == length
		    && 0 == memcmp(predefined[ i ].str, flat, length))
		{
			free(flat);
			return DEBUG_RETURN(predefined[ i ].ref);
		}
		
	free(flat);
	return DEBUG_RETURN(TOK_ID);
}

long int
get_long(const char * str, size_t length, int base)
{
	char * flat, * end;
	intmax_t val;

	DEBUG_ENTER();

	flat = flatten(str, &length);
	if (NULL == flat)
		return DEBUG_FAIL(0);

	val = strtoll(flat, &end, base);
	/* FIXME: We need to determine whether or not this is unsigned, long or long long by looking at the suffix... */
	free(flat);
	if (end == flat)
		return DEBUG_FAIL(0);

	return DEBUG_RETURN(val);
}

int
get_symref(const char * str, size_t length, int def_type)
{
	const struct symbol_table * ptr = table;
	struct symbol_table * new_ptr;
	char * flat;

	DEBUG_ENTER();

	flat = flatten(str, &length);
	if (NULL == flat)
		return DEBUG_FAIL(0);
	
	while (NULL != ptr) {
		if (ptr->entry.length == length
		    && 0 == memcmp(ptr->entry.str, flat, length))
		{
			free(flat);
			return DEBUG_RETURN(ptr->entry.ref);
		}
		
		ptr = ptr->next;
	}

	new_ptr = malloc(sizeof(*ptr));
	if (NULL == new_ptr) {
		free(flat);
		return DEBUG_FAIL(0);
	}

	new_ptr->next = table;
	new_ptr->entry.length = length;
	new_ptr->entry.str = flat;

	switch (def_type) {
	case SYMBOL__DEFINED:
		new_ptr->entry.ref = last_defined++;
		break;
	case SYMBOL__UNDEFINED:
		new_ptr->entry.ref = last_undefined++;
		break;
	default:
		new_ptr->entry.ref = last_unknown++;
		break;
	}

	table = new_ptr;

	/* NOTE: flat is now owned by table */

	return DEBUG_RETURN(new_ptr->entry.ref);
}

char *
flatten(const char * str, size_t * const plength)
{
	const char * end;
	char * flat, * ptr;
	size_t length;

	DEBUG_ENTER();
	
	assert(NULL != str);
	assert(NULL != plength);
	assert(0 < *plength);

	length = *plength;
	flat = ptr = malloc(length + 1);
	if (NULL == flat)
		return DEBUG_FAIL(NULL);
	
	end = str + length;
	
	while (str < end) {
		char * split;
	
		assert(ptr < flat + *plength);
		
		if (NULL != (split = strstr(str, SPLIT))) {
			memcpy(ptr, str, (split - str) * sizeof(*ptr));
			ptr += split - str;
			length -= split - str + CONST_STRLEN(SPLIT);
			str = split + CONST_STRLEN(SPLIT);
		} else if (NULL != (split = strstr(str, SPLIT_DOS))) {
			/* DOS line termination */
			memcpy(ptr, str, (split - str) * sizeof(*ptr));
			ptr += split - str;
			length -= split - str + CONST_STRLEN(SPLIT_DOS);
			str = split + CONST_STRLEN(SPLIT_DOS);
		} else if (NULL != (split = strstr(str, SPLIT_TRI))) {
			/* Trigraph */
			memcpy(ptr, str, (split - str) * sizeof(*ptr));
			ptr += split - str;
			length -= split - str + CONST_STRLEN(SPLIT_TRI);
			str = split + CONST_STRLEN(SPLIT_TRI);
		} else if (NULL != (split = strstr(str, SPLIT_TRI_DOS))) {
			/* Trigraph + DOS line termination */
			memcpy(ptr, str, (split - str) * sizeof(*ptr));
			ptr += split - str;
			length -= split - str + CONST_STRLEN(SPLIT_TRI_DOS);
			str = split + CONST_STRLEN(SPLIT_TRI_DOS);
		} else {
			memcpy(ptr, str, length);
			ptr += length;
			str += length;
			break;
		}
	}

	assert(str == end);
	assert(ptr <= flat + *plength);

	if (*plength != ptr - flat) {
		DEBUG(DINFO, "Flattened \"%.*s\" to \"%.*s\"\n", *plength, end - *plength, ptr - flat, flat);
	}
	*plength = ptr - flat;
	flat[ *plength ] = '\0';

	DEBUG(DINFO, "Result : \"%s\"\n", flat);

	return DEBUG_RETURN(flat);
}
