#!/bin/sh

CWD="$(pwd)"

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

make_dir() {
	state "$1" \
	> /dev/null \
	2> /dev/null && return

	mkdir -p "$1"
}

assert_file build.sh

. ./build.sh

srcdir="$CWD/src"
outdir="$CWD/out"
pkgdir="$outdir/$pkgname-$pkgver"
pkgfile="$outdir/$pkgname-$pkgver.tar.zst"

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
	&& fatal 'Package already built'

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

	make_dir "$pkgdir"
	make_dir "$outdir"

	cd "$srcdir"

	pkgdir="$pkgdir" package

	cd "$srcdir"

	install -d "$pkgdir/usr/share/iglupkg"

	pkgmetafile="$pkgdir/usr/share/iglupkg/$pkgname"

	genmeta > "$pkgmetafile"

	tar -I zstd -cf "$pkgfile" *
fi
