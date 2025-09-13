#!/bin/sh -e
pkgrel=0
muon_base_args="-Dbuildtype=release \
-Dprefix=/usr \
-Dlibexecdir=lib \
-Ddefault_library=shared \
-Dwarning_level=0 \
-Dwerror=false"

set -e

export HOST_ARCH=$(uname -m)

if uname -o | grep GNU >/dev/null; then
	export HOST_TRIPLE="$HOST_ARCH-unknown-linux-gnu"
else
	export HOST_TRIPLE="$HOST_ARCH-unknown-linux-musl"
fi

command -V bad 2>/dev/null || bad() {
	shift
	"$@"
}

bad --gmake command -V gmake 2> /dev/null || gmake() {
	make "$@"
}

usage() {
	echo "usage: $(basename $0) [fbp]"
	echo "usage: f: fetch"
	echo "usage: b: build"
	echo "usage: p: package"
	echo "version: 0.1.1"
	exit 1
}

fatal() {
	echo "ERROR: $@"
	usage
	exit 1
}

error() {
	echo "ERROR: $@"
	exit 1
}

warn() {
	echo "WARNING: $@"
}

to_run=
while [ ! -z "$1" ]; do
	case "$1" in
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
		x)
			to_run="x"
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

export TRIPLE="$ARCH-unknown-linux-musl"
[ -z "$CC" ] && export CC=cc
[ -z "$CXX" ] && export CXX=c++
export AR=ar
export RANLIB=ranlib
export CFLAGS="-O3"
export CXXFLAGS=$CFLAGS

export JOBS=$(nproc)

[ -f build.sh ] || fatal 'build.sh not found'

. ./build.sh

if command -V iglu 2>/dev/null; then
	[ -z "$mkdeps" ] || iglu has $mkdeps \
		|| warn 'missing make dependancies'
	[ -z "$deps" ] || iglu has $deps \
		|| warn 'missing runtime dependancies'
fi

srcdir="$(pwd)/src"
outdir="$(pwd)/out"
pkgdir="$(pwd)/out/install.$pkgver"

[ -d "$pkgdir" ] || warn "package already built. Pass f b or p."

_shlib_requires() {
	find . -type f '!' -type l | while read -r f
	do
		readelf --elf-output-style=LLVM "$f" 2>/dev/null >/dev/null || continue
		if ! readelf -h "$f" | grep 'Type:' | grep 'DYN' >/dev/null 2>/dev/null
		then
			continue
		fi
		readelf --needed-libs "$f" | grep -E -v '\[|\]'
	done | sort -u | while read -r l
	do
		find . -name "$l" -exec false {} + || continue
		printf '%s ' "$l"
	done
}

_verify_shlibs() {
	for shlib in "$shlibs"
	do
		if find . -name "$shlib" -exec false {} +
		then
			error "shlib $shlib is not provided"
		fi
	done
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

	for subpkg in $subpkgs
	do
		cd "$pkgdir"

		subpkgdir="$outdir/$subpkg.$pkgver"
		mkdir -p "$outdir/$subpkg.$pkgver"

		shlibs=
		deps=
		san_deps=
		command -V $subpkg | grep function >/dev/null || error "function for $subpkg not found"
		$subpkg >/dev/null

		for dep in $deps
		do
			if printf '%s\n' "$dep" | grep '\(==\)\|\(>=\)\|\(=\)' >/dev/null
			then
				san_deps="$san_deps $dep"
			elif printf '%s\n' $subpkgs | grep '^'"$dep"'$'
			then
				san_deps="$san_deps $dep-$pkgver""_$pkgrel"
			else
				san_deps="$san_deps $dep>=0"
			fi
		done

		$subpkg | while read -r subpkg_file
		do
			[ -d "$subpkg_file" ] && continue
			file_dir=$(dirname "$subpkgdir/$subpkg_file")
			mkdir -p "$file_dir"
			mv "$subpkg_file" "$file_dir"
		done
		cd $subpkgdir
		[ -z "$shlibs" ] || _verify_shlibs
		[ -z "$desc" ] && desc="TODO"
		shlib_requires="$(_shlib_requires)"
		cd $outdir
		xbps-create -A $ARCH-musl -n $subpkg-$pkgver\_$pkgrel \
			--shlib-requires "$shlib_requires" --shlib-provides "$shlibs" \
			-s "$desc" -D "$san_deps" $subpkgdir
	done
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
