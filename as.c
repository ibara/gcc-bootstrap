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
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern char **environ;

/*
 * GNU as-compatible frontend for Clang as.
 * For systems that don't ship GNU as but ship Clang, like FreeBSD.
 * Most notably, allows for omission of input file entirely;
 * assumes stdin in that situation.
 */

int
main(int argc, char *argv[])
{
	char **av;
	pid_t pid;
	int i, status;
	bool have_input = false, have_output = false;

	/*
	 * `as' becomes `clang -c -x assembler'
	 * In other words, add 3 to argc.
	 *
	 * If no output file, we need to add another 2 to argc.
	 * `-o' and `a.out'
	 *
	 * If no input file, we need to add another 1 to argc.
	 * `-'
	 *
	 * Plus 1 for the final NULL in all cases.
	 *
	 * Total additional potential args = 7
	 */

	if ((av = malloc((argc + 7) * sizeof(char *))) == NULL)
		err(1, "malloc failed");

	av[0] = "/usr/bin/clang";
	av[1] = "-c";
	av[2] = "-x";
	av[3] = "assembler";

	for (i = 1; i < argc; ++i) {
		av[i + 3] = argv[i];

		if (!strncmp(argv[i], "-o", 2)) {
			have_output = true;
			continue;
		}

		if (argv[i][0] == '-') {
			if (!strcmp(argv[i], "-"))
				have_input = true;
			continue;
		}

		have_input = true;
	}

	if (!have_output) {
		av[i + 3] = "-o";
		++i;

		av[i + 3] = "a.out";
		++i;
	}

	if (!have_input) {
		av[i + 3] = "-";
		++i;
	}

	av[i + 3] = NULL;

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
