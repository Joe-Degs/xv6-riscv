/* pingpong uses pipes to transfer a byte between a parent and child */
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

/* write message to stderr and exit with status */
void err_exit(const char *msg)
{
	fprintf(2, msg);
	exit(1);
}

int main(int argc, char *argv[])
{
	int fds[2];
	if (pipe(fds) < 0)
		err_exit("pingpong: failed to create pipe\n");

	if (fork() == 0) {
		/* child: wait for ping, send pong */
		char ball;
		if (read(fds[0], &ball, 1) < 1)
			err_exit("pingpong c: pipe read failed\n");

		printf("%d: recieved ping %c\n", getpid(), ball);

		if (write(fds[1], &ball, 1) != 1)
			err_exit("pingpong c: pipe write failed\n");

		exit(0);
	} else {
		/* parent: send ping, wait for pong */
		char ball;
		if (write(fds[1], "o", 1) != 1)
			err_exit("pingpong p: pipe write failed\n");

		wait(0); /* wait for child to read and write to channel */
		close(fds[1]);

		if (read(fds[0], &ball, 1) != 1)
			err_exit("pingpong p: pipe write failed\n");
		close(fds[0]);

		printf("%d: recieved pong %c\n", getpid(), ball);
	}
	exit(0);
}
