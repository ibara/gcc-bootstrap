/*
 * Copyright (c) 2025 Brian Callahan <bcallah@openbsd.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include <sys/wait.h>

#include <err.h>
#include <stdlib.h>
#include <unistd.h>

extern char **environ;

int
main(int argc, char *argv[])
{
	char **av;
	pid_t pid;
	int i, status;

#if defined(__APPLE__) && defined(__MACH__)
	i = 2;
#else
	i = 4;
#endif

	if ((av = malloc((argc + i) * sizeof(char *))) == NULL)
		err(1, "malloc failed");

#if defined(__APPLE__) && defined(__MACH__)
	av[0] = "/usr/bin/as";
#else
	av[0] = "/usr/bin/clang";
	av[1] = "-c";
	av[2] = "-x";
	av[3] = "assembler";
#endif

	for (i = 1; i < argc; ++i) {
#if defined(__APPLE__) && defined(__MACH__)
		av[i] = argv[i];
#else
		av[i + 3] = argv[i];
#endif
	}

#if defined(__APPLE__) && defined(__MACH__)
	av[i++] = "-Wno-overriding-deployment-version";
	av[i] = NULL;
#else
	av[i + 3] = NULL;
#endif

	switch ((pid = fork())) {
	case -1:
		free(av);
		av = NULL;
		err(1, "fork failed");
	case 0:
		execve(av[0], av, environ);
		_exit(127);
	default:
		if (waitpid(pid, &status, 0) == -1) {
			free(av);
			av = NULL;
			err(1, "waitpid failed");
		}
	}

	i = WIFEXITED(status) ? WEXITSTATUS(status) : 1;

	free(av);
	av = NULL;

	return i;
}
