#!/bin/sh
set -e

export HOST_ARCH=$(uname -m)
export HOST_TRIPLE="$HOST_ARCH-unknown-linux-musl"
cross=
if [ -z "$ARCH" ]; then
	export ARCH=$HOST_ARCH
else
	cross=-$ARCH
fi
export TRIPLE="$ARCH-unknown-linux-musl"
export CC=cc
export CXX=c++
export AR=ar
export RANLIB=ranlib
export CFLAGS="-flto -O3"
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
	build
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
	tar --owner=0 --group=0 -cf ../$pkgname$cross.$pkgver.tar.zstd * -I zstd
}

if [ -z "$@" ]; then
	[ -f "$srcdir/.fetched" ] || _f
	[ -f "$srcdir/.built" ] || _b
	_p
else
	while [ ! -z "$1" ]; do
		_"$1"
		shift
	done
fi
