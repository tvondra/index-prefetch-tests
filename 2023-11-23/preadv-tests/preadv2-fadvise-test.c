#define _GNU_SOURCE

#include <sys/fcntl.h>
#include <sys/unistd.h>
#include <sys/uio.h>
#include <sys/time.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>

/* simple RNG using a prime number */
#define RANDOM_OFFSET(idx, nblocks)	(((idx) * 69239) % (nblocks)) * 8192

/* calculate difference between two timestamps */
#define TIME_DELTA(time_start, time_end) \
	((time_end).tv_sec - (time_start).tv_sec) * 1000000L + ((time_end).tv_usec - (time_start).tv_usec)

int
main(int argc, char **argv)
{
	int			fd;
	off_t		file_size;
	char	   *buff;
	int			ncalls,
				nhits,
				nmisses,
				nerrors;
	long int	nblocks;
	int			block_size,
				check_size;

	struct timeval	time_start;
	struct timeval	time_end;

	/* open file and determine how large it is */

	if (argc != 4)
	{
		printf("not enough arguments: ./preadv2-test filename block-size check-size\n");
		return 1;
	}

 	fd = open(argv[1], 0, O_RDONLY);
	if (fd < 0)
	{
		printf("failed to open file: %d", errno);
		return 1;
	}

	file_size = lseek(fd, 0, SEEK_END);
	if (file_size < 0)
	{
		printf("failed to determine file size: %d", errno);
		return 1;
	}

	block_size = atoi(argv[2]);
	if ((block_size < 0) || (block_size > 1024*1024))
	{
		printf("incorrect block size: %d", block_size);
		return 1;
	}

	check_size = atoi(argv[3]);
	if ((check_size < 0) || (check_size > 1024*1024))
	{
		printf("incorrect check size: %d", block_size);
		return 1;
	}

	/* number of blocks in the file  */
	nblocks = file_size / block_size;
	buff = malloc(block_size);

	printf("file: %s  size: %d (%d)  block %d  check %d\n",
		   argv[1], file_size, nblocks, block_size, check_size);

	/* run preadv2 in a loop on blocks in random order */
	gettimeofday(&time_start, NULL);

	ncalls = nhits = nmisses = nerrors = 0;
	for (int i = 0; i < nblocks; i++)
	{
		struct iovec	iov[1];
		ssize_t			len;

		iov[0].iov_base = buff;
		iov[0].iov_len = check_size;

		len = preadv2(fd, iov, 1, RANDOM_OFFSET(i, nblocks), RWF_NOWAIT);

		if (len == check_size)
		{
			nhits++;
		}
		else
		{
			posix_fadvise(fd, RANDOM_OFFSET(i, nblocks), block_size, POSIX_FADV_WILLNEED);
			nmisses++;
		}

		ncalls++;
	}

	gettimeofday(&time_end, NULL);

	/* print some statistics */
	printf("fadvise time %ld us  calls %d  hits %d  misses %d\n",
		   TIME_DELTA(time_start, time_end), ncalls, nhits, nmisses);

	/* now actually read the data */
	gettimeofday(&time_start, NULL);

	ncalls = nhits = nmisses = nerrors = 0;
	for (int i = 0; i < nblocks; i++)
	{
		struct iovec	iov[1];
		ssize_t			len;

		iov[0].iov_base = buff;
		iov[0].iov_len = block_size;

		len = preadv2(fd, iov, 1, RANDOM_OFFSET(i, nblocks), 0);

		if (len == block_size)
			nhits++;
		else
			nmisses++;

		ncalls++;
	}

	gettimeofday(&time_end, NULL);

	/* print some statistics */
	printf("preadv2 time %ld us  calls %d  hits %d  misses %d\n",
		   TIME_DELTA(time_start, time_end), ncalls, nhits, nmisses);
}
