/* sleep pauses the execution for the number of clock ticks supplied to the
 * sleep command */
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

int main(int argc, char *argv[])
{
	if (argc < 2) {
		fprintf(2, "Usage: sleep SECONDS...\n");
	}
	//int a = atoi(argv[1]);
	// fprintf(1, "sleeping for %d ticks\n", a);
	sleep(atoi(argv[1]));
	exit(0);
}
