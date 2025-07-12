DESTDIR =
SHELL = /bin/sh

srcdir = .

AWK = awk
CP = cp
ED = ed

CFLAGS = -g -O2 -Wall -pedantic
CPPFLAGS = -I. -I$(srcdir) -I$(srcdir)/include

.SUFFIXES:
.SUFFIXES: .c .o .tab.h .tab.c .y .yy.c .l

objects = debug.o f_string.o grammar.tab.o lex.yy.o options.o pp_cond.o symbol.o

%.tab.c %.tab.h: %.y
	$(YACC) $(YFLAGS) -o $*.tab.c $<

%.yy.c: %.l
	$(LEX) $(LFLAGS) -o $@ $<

exifdef : $(objects)
	$(CC) -o $@ $^ -ll

clean :
	-$(RM) -f *.o *.tab.c *.tab.h *.yy.c *~ core exifdef Makefile.bak

depend: $(objects:.o=.c)
	for i in $^ ; do						      \
		$(CC) -MM $(CPPFLAGS) "$(srcdir)/$$i" |			      \
			$(AWK) '{					      \
	if ($$1 != prev) { if (rec != "") print rec; rec = $$0; prev = $$1; } \
	else { if (length(rec $$2) > 78) { print rec; rec = $$0; }	      \
	else rec = rec " " $$2 } }					      \
				END { print rec } ' >> makedep;		      \
	done

	echo '/^# DO NOT DELETE THIS LINE/+2,$$d' >eddep
	echo '$$r makedep' >>eddep
	echo 'w' >>eddep
	$(CP) Makefile Makefile.bak
	$(ED) - Makefile < eddep
	$(RM) eddep makedep
	echo '# DEPENDENCIES MUST END AT END OF FILE' >> Makefile
	echo '# IF YOU PUT STUFF HERE IT WILL GO AWAY' >> Makefile
	echo '# see make depend above' >> Makefile

.PHONY : clean depend

# DO NOT DELETE THIS LINE -- make depend uses it
# DEPENDENCIES MUST END AT END OF FILE
debug.o: debug.c include/debug.h
f_string.o: f_string.c include/debug.h include/f_string.h grammar.tab.h
grammar.tab.o: grammar.tab.c include/debug.h include/f_string.h \
  grammar.tab.h include/options.h include/pp_cond.h include/symbol.h
lex.yy.o: lex.yy.c include/debug.h include/f_string.h grammar.tab.h \
  include/symbol.h
options.o: options.c include/debug.h include/options.h include/symbol.h
pp_cond.o: pp_cond.c include/debug.h include/f_string.h grammar.tab.h \
  include/pp_cond.h include/symbol.h
symbol.o: symbol.c include/debug.h grammar.tab.h include/symbol.h
# DEPENDENCIES MUST END AT END OF FILE
# IF YOU PUT STUFF HERE IT WILL GO AWAY
# see make depend above
