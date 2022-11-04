/* set up a pipeline to serve as a prime sieve */
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

void perr(char *msg)
{
	fprintf(2, msg);
	exit(1);
}

/* convert integer to 4 byte array */
static inline void itoc(uchar b[4], int num)
{
	
	/* n[0] = (i >> 24) & 0xff;
	   n[1] = (i >> 16) & 0xff;
	   n[2] = (i >> 8) & 0xff;
	   n[3] = i & 0xff;
	*/
	for (int i = 0; i < 4; i++) {
		b[4-(i+1)] = (num >> (i << 3)) & 0xff;
	}
	/* printf("itoc: %x %x %x %x\n", b[0], b[1], b[2], b[3]); */
}

/* covert 4 byte array to integer */
static inline int ctoi(uchar b[4])
{
	int n = 0;
	for (int i = 0; i < 4; i++) {
		int a = 4 - (i + 1);
		n |= b[i] << (a << 3);
	}
	return n;
}

int get(int fd, uchar b[4])
{
	int n;
	if ((n = read(fd, b, 4)) < 0)
		perr("primes: error reading from pipe\n");
	if (!n)
		return n;
	return ctoi(b);
}

void send(int fd, uchar b[4])
{
	if (write(fd, b, 4) != 4)
		perr("primes: error writing to pipe\n");
}

/* filter reads numbers from its read head `in`, filters out multiples of `prime`
 * and writes non-multiples to its write head `out`
 */
void filter(int prime, int in, int out)
{
	uchar b[4];
	int i;
	while ((i = get(in, b)) != 0) {
		if (i%prime != 0) {
			send(out, b);
		}
	}
	close(in);
	close(out);
}

void counter(int out, int max)
{
	uchar b[4];
	for (int i = 2; i <= max; i++) {
		itoc(b, i);
		send(out, b);
	}
	close(out);
}

void ppipe(int fd[2]) {
	if (pipe(fd) < 0) {
		perr("failed to open pipe");
	}
}

int main(int argc, char *argv[])
{
	if (argc < 2)
		perr("Usage: primes NUMBER");
	int n;
	if ((n = atoi(argv[1])) < 2)
			perr("primes: must be greater than 2");

	int fd[2];
	ppipe(fd);
	int in = fd[0], out = fd[1];
	if (fork() == 0) {
		// start the counter child process
		counter(out, n);
	}
	uchar b[4];
	for (int i = get(in, b); i != 0; i = get(in, b)) {
		printf("prime: %d\n", i);
		int nfd[2];
		ppipe(nfd);
		if (fork() == 0) {
			int r = dup(in);
			filter(i, r, nfd[1]);
			exit(0);
		}
		in = nfd[0];
	}
	close(in);
	close(out);
	exit(0);
}
