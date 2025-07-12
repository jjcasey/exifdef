#ifndef F_STRING_H
#define F_STRING_H 1

#include "grammar.tab.h"

#define CLEAR_F_STRING(x)	memset((x), 0, sizeof(*(x)))

struct f_string make_f_string(const char * str, size_t length, size_t trailing_ws);
struct f_string empty_f_string(void);
void release_f_string(struct f_string * x);

struct f_string combine_f_string(struct f_string * x, struct f_string * y);
struct f_string combine3_f_string(struct f_string * x, struct f_string * y, struct f_string * z);
void append_ws_f_string(struct f_string * x, struct f_string * y);

void convert_elif_to_if_f_string(struct f_string * elif);
void convert_elif_to_else_f_string(struct f_string * elif, struct f_string * expr);
void truncate_truth_f_string(struct f_string * str, int truth);

#endif /* F_STRING_H */
