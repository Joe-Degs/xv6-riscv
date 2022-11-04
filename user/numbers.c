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
	
	for (int i = 0; i < 4; i++) {
		b[4-(i+1)] = (num >> (i * 8)) & 0xff;
	}
	/* printf("itoc: %x %x %x %x\n", b[0], b[1], b[2], b[3]); */
}

/* covert 4 byte array to integer */
static inline int ctoi(uchar b[4])
{
	int i = (int)b[3] | (int)b[2] << 8 | (int)b[1] << 16 | (int)b[0] << 24;
	return i;
}

static inline void primes(int n)
{
	printf("primes %d\n", n);
}

int get(int fd, uchar b[4])
{
	int n;
	if ((n = read(fd, b, 4)) < 0)
		perr("primes: error reading number\n");

	if (!n)
		return n;
	return ctoi(b);
}

void send(int fd, uchar b[4])
{
	if (write(fd, b, 4) != 4)
		perr("primes: error sending number\n");
}

void cclose(int fd, int pid)
{
	close(fd);
	printf("closed: %d\n", pid);
}

int main(int argc, char *argv[])
{
	if (argc < 2)
		perr("Usage: primes NUMBER");
	int n;
	if ((n = atoi(argv[1])) < 2)
			perr("primes: must be greater than 2");

	int fds[2];
	if (pipe(fds) < 0)
		perr("primes: could not open pipe\n");

	if (fork() == 0) {
		close(fds[1]);
		uchar b[4];
		int n;
		while ((n = get(fds[0], b)) > 0)
			primes(n);

		close(fds[0]);
		printf("got before exit %d\n", n);
		exit(0);
	}

	// close(fds[0]);
	uchar bytes[4];
	for (int i = 1; i <= n; i++) {
		itoc(bytes, i);
		send(fds[1], bytes);
	}

	close(fds[0]);
	close(fds[1]);
	int retval;
	wait(&retval);
	exit(retval);
}
