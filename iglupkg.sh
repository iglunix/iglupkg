#!/bin/sh
set -e

export HOST_ARCH=$(uname -m)
export HOST_TRIPLE="$HOST_ARCH-unknown-linux-musl"

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
		--for-cross)
			echo 'INFO: for cross'
			FOR_CROSS=1
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
export CFLAGS="-O3"
export CXXFLAGS=$CFLAGS

export JOBS=$(nproc)

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

[ -f build.sh ] || fatal 'build.sh not found'

. ./build.sh

srcdir="$(pwd)/src"
outdir="$(pwd)/out"
pkgdir="$(pwd)/out/$pkgname.$pkgver"

rm -rf "$outdir"

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
	rm -rf "$srcdir"
	mkdir -p "$srcdir"
	cd "$srcdir"
	fetch
	cd "$srcdir"
	:> .fetched
}

_b() {
	cd "$srcdir"
	[ -f .fetched ] || fatal 'must fetch before building'
	MAKEFLAGS=-j"$JOBS" build
	cd "$srcdir"
	:> .built
}

_p() {
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
	_p
else
	set -- $to_run

	while [ ! -z "$1" ]; do
		_"$1"
		shift
	done
fi
