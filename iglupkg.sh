#!/bin/sh
set -e

export HOST_ARCH=$(uname -m)
export HOST_TRIPLE="$HOST_ARCH-unknown-linux-musl"

command -V bad 2>/dev/null || bad() {
	shift
	"$@"
}

usage() {
	echo "usage: $(basename $0) [fbp]"
	exit 1
}

fatal() {
	echo "ERROR: $@"
	exit 1
}

warn() {
	echo "WARNING: $@"
}

to_run=
while [ ! -z "$1" ]; do
	case "$1" in
		--with-cross=*)
			ARCH=$(echo "$1" | cut -d'=' -f2)
			[ -z "$ARCH" ] && fatal '--with-cross=<arch> requires an argument'
			echo "INFO: cross compiling for $ARCH"
			WITH_CROSS="$ARCH"
			;;
		--with-cross)
			fatal '--with-cross=<arch> requires an argument'
			;;
		--with-cross-dir=*)
			WITH_CROSS_DIR=$(echo "$1" | cut -d'=' -f2)
			[ -z "$WITH_CROSS_DIR" ] && fatal '--with-cross-dir=<sysroot> requires an argument'
			[ -d "$WITH_CROSS_DIR" ] 2>/dev/null || warn "$WITH_CROSS_DIR does not exist"
			echo "INFO: using toolchain libraries from $WITH_CROSS_DIR"
			;;
		--with-cross-dir)
			fatal '--with-cross-dir=<sysroot> requires an argument'
			;;
		--for-cross)
			echo 'INFO: for cross'
			FOR_CROSS=1
			;;
		--for-cross-dir=*)
			FOR_CROSS_DIR=$(echo "$1" | cut -d'=' -f2)
			[ -z "$FOR_CROSS_DIR" ] && fatal '--for-cross-dir=<sysroot> requires an argument'
			echo "INFO: packaging for prefix $FOR_CROSS_DIR"
			;;
		--for-cross-dir)
			fatal '--for-cross-dir=<sysroot> requires an argument'
			;;
		fbp)
			to_run="f b p"
			;;
		fb)
			to_run="f b"
			;;
		f)
			to_run="f"
			;;
		bp)
			to_run="b p"
			;;
		b)
			to_run="b"
			;;
		p)
			to_run="p"
			;;
		*)
			fatal "invalid argument $1"
			;;
	esac
	shift
done

[ -z "$WITH_CROSS_DIR" ] && WITH_CROSS_DIR=/usr/$ARCH-linux-musl
[ -z "$FOR_CROSS_DIR" ] && FOR_CROSS_DIR=/usr/$ARCH-linux-musl

if [ -z "$ARCH" ]; then
	export ARCH=$HOST_ARCH
fi

if [ ! -z "$FOR_CROSS" ]; then
	cross=-$ARCH
fi
export TRIPLE="$ARCH-unknown-linux-musl"
export CC=cc
export CXX=c++
export AR=ar
export RANLIB=ranlib
export CROSS_EXTRA_LDFLAGS="--target=$TRIPLE --sysroot=$WITH_CROSS_DIR"
export CFLAGS="-O3"
export CROSS_EXTRA_CFLAGS="--target=$TRIPLE --sysroot=$WITH_CROSS_DIR"
export CXXFLAGS=$CFLAGS
export CROSS_EXTRA_CXXFLAGS="$CROSS_EXTRA_CFLAGS -nostdinc++ -isystem $WITH_CROSS_DIR/include/c++/v1/"

auto_cross() {
	[ -z "$WITH_CROSS" ] && return
	export CFLAGS="$CFLAGS $CROSS_EXTRA_CFLAGS"
	export CXXFLAGS="$CFLAGS $CROSS_EXTRA_CXXFLAGS"
	export LDFLAGS="$CROSS_EXTRA_LDFLAGS"
}

export JOBS=$(nproc)

[ -f build.sh ] || fatal 'build.sh not found'

. ./build.sh

if command -V iglu 2>/dev/null; then
	[ -z "$mkdeps" ] || iglu has $(echo $mkdeps | sed -e "s|:| |g") \
		|| fatal 'missing make dependancies'
	[ -z "$deps" ] || iglu has $(echo $deps | sed -e "s|$|$cross|" -e "s|:|$cross |g") \
		|| fatal 'missing runtime dependancies'
fi

srcdir="$(pwd)/src"
outdir="$(pwd)/out"
pkgdir="$(pwd)/out/$pkgname$cross.$pkgver"

[ -d "$pkgdir" ] || warn "package already built. Pass f b or p."

_genmeta() {
	echo "[pkg]"
	echo "pkgname=$pkgname"
	echo "pkgver=$pkgver"
	echo "deps=$deps"
	echo ""
	echo "[license]"
	license
	echo ""
	echo "[backup]"
	backup
	echo ""
	echo "[fs]"

	cd "$pkgdir"
	find *
	cd "$srcdir"
}

_f() {
	rm -rf "$pkgdir"
	rm -rf "$srcdir"
	mkdir -p "$srcdir"
	cd "$srcdir"
	fetch
	cd "$srcdir"
	:> .fetched
}

_b() {
	rm -rf "$pkgdir"
	cd "$srcdir"
	[ -f .fetched ] || fatal 'must fetch before building'
	MAKEFLAGS=-j"$JOBS" build
	cd "$srcdir"
	:> .built
}

_p() {
	rm -rf "$pkgdir"
	cd "$srcdir"
	[ -f .built ] || fatal 'must build before packaging'
	mkdir -p "$pkgdir"
	package
	install -d "$pkgdir/usr/share/iglupkg/"
	cd "$srcdir"
	_genmeta > "$pkgdir/usr/share/iglupkg/$pkgname$cross"
	cd "$pkgdir"
	tar --owner=0 --group=0 -cf ../$pkgname$cross.$pkgver.tar.zst * -I zstd
}

if [ -z "$to_run" ]; then
	[ -f "$srcdir/.fetched" ] || _f
	[ -f "$srcdir/.built" ] || _b
	[ -d "$pkgdir" ] || _p
else
	set -- $to_run

	while [ ! -z "$1" ]; do
		_"$1"
		shift
	done
fi
