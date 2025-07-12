This program was written by Johnny Casey <jjcasey@pobox.com>.  The program
is being distributed under GPL.

I wrote this program sometime in 2004 (it hasn't been touched much since then).

There currently is not a website for this software.

I have tested this software on my own codebase, but that does not mean that
there aren't possible bugs.

To compile, you will need a lex and yacc program appropriate for your platform.
I tested the code with flex and bison.  If you run into problems, send me a
note and any possible work arounds.  Beyond that, the code is pretty much
straight C.

I wrote this because I wanted a tool that was more than just a regular
expression and some added logic.  The tool was written following the C
grammar.

Command line takes three arguments:
 -d  Turns on debugging
 -D  Defines a variable such that #ifdef will return true.
     May be specified multiple times.
 -U  Undefines a variable such that #ifdef will return false.
     May be specified multiple times.

See COPYING for license information.

NOTE: The code will NOT remove #if 0 ... blocks, but WILL remove #elif 0 ... blocks.  This is to facilitate using #if 0 to comment large blocks of code.
