#ifndef SYMBOL_H
#define SYMBOL_H

#define is_undefined(x)	(SYMBOL__UNDEFINED == ((x) & SYMBOL_MASK))
#define is_defined(x)	(SYMBOL__DEFINED == ((x) & SYMBOL_MASK))
#define is_unknown(x)	(SYMBOL__UNKNOWN == ((x) & SYMBOL_MASK))

#define FOLLOWS(x)	((SYMBOL__ ## x) + SYMBOL_INC)

enum SYMBOL_FLAGS {
	SYMBOL_INC = 1 << (8 * sizeof(int) - 3),
	SYMBOL__PREDEFINED = 0,
	SYMBOL__DEFINED = FOLLOWS(PREDEFINED),
	SYMBOL__UNDEFINED = FOLLOWS(DEFINED),
	SYMBOL__UNKNOWN = FOLLOWS(UNDEFINED),

	SYMBOL_MASK = SYMBOL__PREDEFINED | SYMBOL__DEFINED | SYMBOL__UNDEFINED | SYMBOL__UNKNOWN
};

#undef FOLLOWS

int get_symbol(const char * str, size_t length);
long int get_long(const char * str, size_t length, int base);
int get_symref(const char * str, size_t length, int def_type);

#endif /* SYMBOL_H */
