#include <unistd.h>
#include <string.h>
#include "debug.h"
#include "options.h"
#include "symbol.h"

int
parse_options(int argc, char * const argv[])
{
	int c;

	DEBUG_ENTER();
	
	while (-1 != (c = getopt(argc, argv, "dD:U:")))
		switch (c) {
		case 'd':
			debug = ~0;
			break;
				
		case 'D':
			get_symref(optarg, strlen(optarg), SYMBOL__DEFINED);
			break;
		case 'U':
			get_symref(optarg, strlen(optarg), SYMBOL__UNDEFINED);
			break;
			
		default:
			break;
		}

	return DEBUG_RETURN(optind);
}
