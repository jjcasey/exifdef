#ifndef PP_COND_H
#define PP_COND_H 1

#include "grammar.tab.h"

struct pp_cond * make_pp_cond(struct f_string * str, struct f_string * code);

struct f_string flatten_if_elif_else(struct pp_cond * if_cond, struct pp_cond * elif_cond, struct pp_cond * else_cond, struct f_string * endif_str);

#endif /* PP_COND_H */
