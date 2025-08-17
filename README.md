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

License
-------
ISC License. See `LICENSE` for more information.
