gcc-bootstrap
=============
A simple to use shell script to bootstrap niche GCC languages on your
machine, such as
[Ada](https://en.wikipedia.org/wiki/Ada_%28programming_language%29)
and
[D](https://dlang.org/).

Usage
-----
```sh
$ ./gcc-bootstrap.sh [options] gcc_ver installdir
```
Where `gcc_ver` is the version number you want to build (e.g., 15.2.0)
and `installdir` is the directory you want to install GCC into.

The options are as follows:
```
  --bootstrap    Download and use bootstrap binaries
  --full         Build all possible GCC languages for your target
  --with-ada     Add Ada to the list of languages to build
  --with-cobol   Add COBOL to the list of languages to build
  --with-d       Add D to the list of languages to build
  --with-fortran Add Fortran to the list of languages to build
  --with-go      Add Go to the list of languages to build
  --with-m2      Add Modula-2 to the list of languages to build
  --with-objc    Add Objective C to the list of languages to build
                 Includes adding Objective C++
```
All other flags that begin with `--` will be passed to the GCC
configure script.

For example, to build GDC 15.1.0 on macOS when you don't already have
GDC installed on your system, and you want to install it to
`/opt/gnu`, you would run:
```sh
$ ./gcc-bootstrap.sh --bootstrap --with-d 15.1.0 /opt/gnu
```

Notes
-----
If you are crossing the macOS Sequoia (15.x) to Tahoe (26.x) barrier,
and installing GCC 15 or earlier, you will need to build and install
the `as.c` wrapper. Assuming you will install GCC to `/opt/gnu`, the
following commands will work:
```sh
$ cc -O2 -o as as.c
$ sudo mkdir -p /opt/gnu/bin
$ sudo install -c -s -m 755 as /opt/gnu/bin/as
```
You then must add the `--with-as=/opt/gnu/bin/as` flag to your GCC
configure script invocation. Failure to do this will result in Ada and
D configure failing. You will need to re-install this `as` wrapper
after GCC installs.

License
-------
ISC License. See `LICENSE` for more information.
