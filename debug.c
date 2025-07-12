#include <stdarg.h>
#include <stdio.h>
#include "debug.h"

int debug = DEBUG_TRACE_FUNCTION_FAIL;

void
debug_print(int level, const char * fmt, ...)
{
	if (debug & level) {
		va_list	args;

		va_start(args, fmt);
		vfprintf(DPRINT == level ? stdout : stderr, fmt, args);
		va_end(args);
	}
} 
