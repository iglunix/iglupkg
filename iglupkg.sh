#!/bin/sh

CWD="$(pwd)"

export CC=cc
export CXX=c++
export ARCH="$(uname -m)"
export TRIPLE="$ARCH-unknown-linux-musl"

fatal() {
	echo "ERROR: $@"
	exit 1
}

warn() {
	echo "WARNING: $@"
}

assert_file() {
	stat "$1" \
	> /dev/null \
	2> /dev/null && return

	fatal "$1 does not exist!"
}

assert_func() {
	command -V "$1" \
	> /dev/null \
	2> /dev/null && return
	fatal "build.sh not sane: $1 not defined!"
}

make_dir() {
	stat "$1" \
	> /dev/null \
	2> /dev/null && return

	mkdir -p "$1"
}

# fetch file, checks the md5sum and only curls if needed
fetch_file() {
	F_NAME=$1
	MD5_SUM=$2
	URL=$3

	stat "$F_NAME" \
	> /dev/null \
	2> /dev/null \
	|| curl -L "$URL" -o "$F_NAME"

	echo "$MD5_SUM  $F_NAME" | md5sum -c || (
		rm "$F_NAME"
		fetch_file $1 $2 $3
	)
}

fetch_tar() {
	F_NAME=$1
	MD5_SUM=$2
	URL=$3

	stat "$F_NAME" \
	> /dev/null \
	2> /dev/null \
	|| (
		curl -L "$URL" -o "$F_NAME"
		tar -xf "$F_NAME"
	)

	echo "$MD5_SUM  $F_NAME" | md5sum -c || (
		rm "$F_NAME"
		fetch_file $1 $2 $3
	)
}

assert_file build.sh

. ./build.sh

assert_func fetch
assert_func build
assert_func package
assert_func backup
assert_func license

srcdir="$CWD/src"
outdir="$CWD/out"
pkgdir="$outdir/$pkgname.$pkgver"
pkgfile="$outdir/$pkgname.$pkgver.tar.zst"

genmeta() {
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

if [ ! -n "$FAKEROOTKEY" ]; then
	stat $pkgfile \
	> /dev/null \
	2> /dev/null \
	&& warn 'Package already built'

	stat $srcdir \
	> /dev/null \
	2> /dev/null \
	&& warn 'Package partially built'

	make_dir "$srcdir"

	cd "$srcdir"

	echo "=========="
	echo " Fetching "
	echo "=========="

	fetch

	cd "$srcdir"

	echo "=========="
	echo " Building "
	echo "=========="

	build

	cd "$CWD"

	fakeroot "$0"
else
	echo "=========="
	echo " Bundling "
	echo "=========="

	stat "$outdir" \
	> /dev/null \
	2> /dev/null && rm -rf "$outdir"

	make_dir "$outdir"
	make_dir "$pkgdir"

	cd "$srcdir"

	pkgdir="$pkgdir" package

	cd "$srcdir"

	install -d "$pkgdir/usr/share/iglupkg"

	pkgmetafile="$pkgdir/usr/share/iglupkg/$pkgname"

	genmeta > "$pkgmetafile"

	cd "$pkgdir"

	tar -I zstd -cf "$pkgfile" *
fi
