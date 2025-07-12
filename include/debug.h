#ifndef DEBUG_H
#define DEBUG_H 1

#define DEBUG_NONE			0x00
#define DEBUG_TRACE_FUNCTION		0x01
#define DEBUG_TRACE_FUNCTION_RETURN	0x02
#define DEBUG_TRACE_FUNCTION_FAIL	0x04
#define DPRINT				~0
#define DINFO				0x100
#define DUNEXPECTED			0x200

#ifndef NDEBUG
#define DEBUG_ENTER()	DEBUG(DEBUG_TRACE_FUNCTION, "=> %s()\n", __FUNCTION__)
#define DEBUG_LEAVE()	DEBUG(DEBUG_TRACE_FUNCTION, "<= %s()\n", __FUNCTION__)

#define DEBUG_RETURN(n)	DEBUG(DEBUG_TRACE_FUNCTION | DEBUG_TRACE_FUNCTION_RETURN,"<= %s() = %#x\n", __FUNCTION__, (n)), (n)
#define DEBUG_FAIL(n)	DEBUG(DEBUG_TRACE_FUNCTION | DEBUG_TRACE_FUNCTION_RETURN | DEBUG_TRACE_FUNCTION_FAIL,"<= %s() at %d FAILED = %#x\n", __FUNCTION__, __LINE__, (n)), (n)
#else
#define DEBUG_ENTER()	do { } while (0)
#define DEBUG_LEAVE()	do { } while (0)

#define DEBUG_RETURN(n)	(n)
#define DEBUG_FAIL(n)	(n)
#endif

#define DEBUG		debug_print

extern int debug;

void debug_print(int level, const char * str, ...);

#endif /* DEBUG_H */
