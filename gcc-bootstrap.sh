#!/bin/sh

# Copyright (c) 2025 Brian Callahan <bcallah@openbsd.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

usage="usage: build-gcc.sh [options] gcc_ver installdir"

uname_m="$(uname -m)"
uname_r="$(uname -r)"
uname_s="$(uname -s)"

macos_x64_bootstrap=1
macos_arm64_bootstrap=2
macos_arm64=0
linux_glibc_x64_bootstrap=3

bootstrap=0
languages="c,c++"
full=0

fatal() {
  printf "error: %s\n" "$1"
  exit 1
}

check_bootstrap() {
  printf "SHA256 check... "

  check="$(echo "$1" | awk '{print $1}')"

  case "$uname_s" in
    Darwin)
      case "$gcc_ver" in
        "15.1.0")
          if [ "$uname_m" = "arm64" ] ; then
            hash="68ae85afa64975f92a5cce0cfec32ef805a067e614c4da932af663c14157d56d"
          else
            fatal "No 15.1.0 bootstrap for macOS x64 (try 15.2.0)"
          fi
          ;;
        "15.2.0")
          if [ "$uname_m" = "x86_64" ] ; then
            hash="963df27ac7ad8acc70596f59ffd77bcd51f944f6f5e1b6a5f189f9baafc089b9"
          else
            fatal "No 15.2.0 bootstrap for macOS arm64 (try 15.1.0)"
          fi
          ;;
        *)
          fatal "Unknown macOS bootstrap version"
          ;;
      esac
      ;;
    Linux)
      case "$gcc_ver" in
        "15.2.0")
          if [ "$uname_m" = "x86_64" ] ; then
            hash="27f0753556771c442390edfd1077bf8ab244ad9d448114c61cf30a7dcc4666db"
          else
            fatal "Unknown Linux arch for 15.2.0 bootstrap"
          fi
          ;;
        *)
          fatal "Unknown Linux bootstrap version"
          ;;
      esac
  esac

  if [ "$check" != "$hash" ] ; then
    fatal "Hash mismatch"
  fi

  echo "ok"
}

check_sha256() {
  printf "SHA256 check... "

  check="$(echo "$1" | awk '{print $1}')"

  case "$gcc_ver" in
    "15.1.0")
      hash="51b9919ea69c980d7a381db95d4be27edf73b21254eb13d752a08003b4d013b1"
      ;;
    "15.2.0")
      hash="7294d65cc1a0558cb815af0ca8c7763d86f7a31199794ede3f630c0d1b0a5723"
      ;;
  esac

  if [ "$check" != "$hash" ] ; then
    fatal "Hash mismatch"
  fi

  echo "ok"
}

find_downloader() {
  # You need curl or wget
  command -v curl > /dev/null 2>&1
  if [ $? -eq 0 ] ; then
    downloader="$(command -v curl) -LO"
  else
    command -v wget > /dev/null 2>&1
    if [ $? -eq 0 ] ; then
      downloader="$(command -v wget)"
    fi
  fi

  if [ -z "$downloader" ] ; then
    fatal "You must install one of curl or wget"
  fi

  printf "Using %s for downloads\n" "$downloader"
}

setup_build() {
  # You need GNU make 3.80 or later
  # Non-Linux platforms often call it gmake
  # That's almost always acceptable
  for make_prog in "gmake" "make" ; do
    command -v $make_prog > /dev/null 2>&1
    if [ $? -eq 0 ] ; then
      $make_prog --version 2>&1 | grep -q "GNU Make"
      if [ $? -ne 0 ] ; then
        continue
      fi
      make_ver="$($make_prog --version)"
      make_ver=$(echo $make_ver | awk '{print $3}')
      make_major=$(echo $make_ver | awk -F '.' '{print $1}')
      make_minor=$(echo $make_ver | awk -F '.' '{print $2}')
      if [ $make_major -gt 3 ] ; then
        make_program="$(command -v $make_prog)"
        break
      else
        if [ $make_major -eq 3 ] ; then
          if [ $make_minor -ge 80 ] ; then
            make_program="$(command -v $make_prog)"
            break
          fi
        fi
      fi
    fi
  done

  if [ -z "$make_program" ] ; then
    fatal "You need GNU make"
  fi

  printf "Using GNU make %s (%s) to build\n" "$make_ver" "$make_program"

  case "$uname_s" in
    Darwin)
      # Turn off Go on Darwin
      if [ $full -eq 1 ] ; then
        languages="ada,c,c++,cobol,d,fortran,m2,objc,obj-c++"
      fi
      # How many CPUs are online?
      ncpu=$(getconf _NPROCESSORS_ONLN)
      # Should really detect one of Xcode or CLT, but I only use CLT...
      extra="--with-sysroot=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"

      if [ "$uname_m" = "arm64" ] ; then
        # Darwin/arm64 support not fully upstreamed to GCC yet...
        if [ "$gcc_ver" != "15.1.0" ] ; then
          echo "warning: Setting GCC version to 15.1.0"
          gcc_ver="15.1.0"
        fi
        # We need GNU patch to apply diff
        command -v gpatch > /dev/null 2>&1
        if [ $? -ne 0 ] ; then
          fatal "You need GNU patch on arm64 macOS"
        fi
        patch="$(command -v gpatch)"
        macos_arm64=1
      fi
      ;;
    FreeBSD|Linux)
      # How many CPUs are online?
      ncpu=$(getconf _NPROCESSORS_ONLN)
      ;;
    *)
      # No idea what we are, assume just 1 CPU to be safe.
      ncpu=1
      ;;
  esac

  # Cap ncpu at 8
  if [ $ncpu -gt 8 ] ; then
    ncpu=8
  fi
}

get_prereqs() {
  original="$(pwd)"
  cd "$(pwd)/gcc-$gcc_ver"
  ./contrib/download_prerequisites
  if [ $? -eq 1 ] ; then
    fatal "Failed to download gcc prerequisites"
  fi
  cd "$original"
}

find_bootstrap() {
  case "$uname_s" in
    Darwin)
      # We have bootstraps going back to 12.7.6 on amd64 (darwin21.6.0)
      # We have bootstraps going back to 15.6 on arm64 (darwin24.6.0)
      major=$(echo $uname_r | awk -F '.' '{print $1}')
      minor=$(echo $uname_r | awk -F '.' '{print $2}')
      if [ "$uname_m" = "x86_64" ] ; then
        if [ $major -eq 21 ] ; then
          minor=$(echo $uname_r | awk -F '.' '{print $2}')
          if [ $minor -ge 6 ] ; then
            return $macos_x64_bootstrap
          fi
        elif [ $major -gt 21 ] ; then
          return $macos_x64_bootstrap
        fi
      elif [ "$uname_m" = "arm64" ] ; then
        if [ $major -eq 24 ] ; then
          if [ $minor -ge 6 ] ; then
            return $macos_arm64_bootstrap
          fi
        elif [ $major -ge 24 ] ; then
          return $macos_arm64_bootstrap
        fi
      fi
    ;;
    Linux)
      # We have bootstraps for glibc x64
      # How to disambiguate for musl?
      if [ "$uname_m" = "x86_64" ] ; then
        return $linux_glibc_x64_bootstrap
      fi
  esac

  fatal "Sorry, no bootstrap available. Please make a pull request."
}

for opt ; do
  case "$opt" in
    --bootstrap)
      # Determine if we have a bootstrap to offer...
      find_bootstrap
      bootstrap=$?
      ;;
    --full)
      languages="all"
      full=1
      ;;
    --with-ada)
      languages="ada,${languages}"
      ;;
    --with-cobol)
      languages="${languages},cobol"
      ;;
    --with-d)
      languages="${languages},d"
      ;;
    --with-fortran)
      languages="${languages},fortran"
      ;;
    --with-go)
      languages="${languages},go"
      ;;
    --with-m2)
      languages="${languages},m2"
      ;;
    --with-objc)
      languages="${languages},objc,obj-c++"
      ;;
    -h|--help)
      echo $usage
      exit 0
      ;;
    --*)
      user_extra="$user_extra $opt"
      ;;
    *)
      if [ -z "$gcc_ver" ] ; then
        gcc_ver="$opt"
      elif [ -z "$installdir" ] ; then
        installdir="$opt"
      else
        fatal $usage
      fi
  esac
done

if [ -z $gcc_ver ] ; then
  fatal "Must specify gcc version number"
fi

if [ -z $installdir ] ; then
  fatal "Must specify gcc installation directory"
fi

printf "Cleaning... "
rm -rf "$(pwd)/gcc-$gcc_ver"
mkdir -p "$(pwd)/gcc-$gcc_ver"
cd "$(pwd)/gcc-$gcc_ver"
echo "done"

find_downloader
setup_build

if [ $bootstrap -gt 0 ] ; then
  bootstrap_url="https://github.com/ibara/gcc-bootstrap/releases/download/binaries"
  case $bootstrap in
    $macos_x64_bootstrap)
      bootstrap_url="${bootstrap_url}/macos-x64.tar.gz"
      ;;
    $macos_arm64_bootstrap)
      bootstrap_url="${bootstrap_url}/macos-arm64.tar.gz"
      ;;
    $linux_glibc_x64_bootstrap)
      bootstrap_url="${bootstrap_url}/linux-glibc-x64.tar.gz"
      ;;
    *)
      fatal "Unknown bootstrap"
      ;;
  esac

  printf "Downloading %s\n" "$bootstrap_url"
  $downloader $bootstrap_url

  check_bootstrap "$(sha256sum $(basename $bootstrap_url) | awk '{print $1}')"

  printf "Untarring... "
  tar xzf $(basename $bootstrap_url)
  hostmachine="$($(pwd)/bootstrap/usr/bin/gcc -dumpmachine)"
  rm -rf "$(pwd)/bootstrap/usr/lib/gcc/$hostmachine/$gcc_ver/include-fixed"
  echo "done"

  export PATH="$(pwd)/bootstrap/usr/bin:$PATH"
fi

url="https://ftpmirror.gnu.org/gnu/gcc/gcc-$gcc_ver/gcc-$gcc_ver.tar.gz"

printf "Downloading %s\n" $url
$downloader $url

check_sha256 "$(sha256sum $(basename $url))"

printf "Untarring... "
tar xzf gcc-$gcc_ver.tar.gz
echo "done"

if [ $macos_arm64 -eq 1 ] ; then
  original="$(pwd)"
  cd "$(pwd)/gcc-$gcc_ver"
  patch_url="https://raw.githubusercontent.com/Homebrew/formula-patches/575ffcaed6d3112916fed77d271dd3799a7255c4/gcc/gcc-15.1.0.diff"
  $downloader $patch_url

  printf "SHA256 check... "
  check="$(sha256sum $(basename $patch_url) | awk '{print $1}')"
  hash="360fba75cd3ab840c2cd3b04207f745c418df44502298ab156db81d41edf3594"
  if [ "$check" != "$hash" ] ; then
    fatal "Hash mismatch"
  fi
  echo "ok"

  patch_file="$(basename $patch_url)"
  $patch -p1 <$patch_file
  cd "$original"
fi

# Force consistency
get_prereqs

rm -rf "$(pwd)/build-gcc-$gcc_ver"
mkdir -p "$(pwd)/build-gcc-$gcc_ver"
cd "$(pwd)/build-gcc-$gcc_ver"

configure_invocation="$(pwd)/../gcc-$gcc_ver/configure --prefix=$installdir --enable-languages=$languages $extra $user_extra"
echo "$configure_invocation"

"$(pwd)/../gcc-$gcc_ver/configure" --prefix=$installdir --enable-languages=$languages $extra $user_extra

echo "$make_program V=1 -j$ncpu"
$make_program V=1 -j$ncpu

if [ $? -eq 0 ] ; then
  echo "$make_program DESTDIR=$(pwd)/../fake-gcc-$gcc_ver install"
  rm -rf "$(pwd)/../fake-gcc-$gcc_ver"
  mkdir -p "$(pwd)/../fake-gcc-$gcc_ver"
  $make_program DESTDIR=$(pwd)/../fake-gcc-$gcc_ver install
  cd "$(pwd)/../fake-gcc-$gcc_ver"
  base="$(ls -1)"
  tar -cz -f gcc-$gcc_ver.tar.gz "$base"
  sudo tar xzf gcc-$gcc_ver.tar.gz -C /
  printf "Installed gcc-%s to %s\n" "$gcc_ver" "$installdir"
else
  fatal "GCC build failed"
fi
