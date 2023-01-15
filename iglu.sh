#!/bin/sh
# usage: iglu [ add | del | has ] <pkg>
#
# WONTFIX:
#  - circular deps shall not be handled

set -e

usage() {
	echo "usage: $(basename $0) [add | del | has | b | ba] <pkg>"
	echo "version: 0.2.0"
	exit 1
}

fatal() {
	echo "ERROR: $@"
	exit 1
}

warn() {
	echo "WARNING: $@"
}

chop_fs() {
	sed -n '/\[fs\]/,/\[backup\]/{/\[fs\]\|\[backup\]/!p}' "$1" \
		| awk '{print length, $0}' | sort -rn | cut -d' ' -f2-
}

continue_interactive() {
	printf '%s' "Do you wish to proceed?: "
	read yn
	case $yn in
		[Yy]* ) echo "Proceeding";;
		[Nn]* ) exit;;
		* ) exit;;
	esac
}

remove() {
	set +e
	rm -f "$@" 2> /dev/null
	while shift 2> /dev/null; do
		if [ -d "/$1" ]; then
			rmdir "/$1" 2> /dev/null
		elif [ -f "/$1" ]; then
			rm -f "/$1" 2> /dev/null
		fi
	done
	set -e
}

assert_deps() {
	for dep in $(grep '^deps=' "$1" | cut -d'=' -f2- | tr ':' '\n'); do
		[ -f "/usr/share/iglupkg/$dep" ] || fatal "Missing dep $dep"
	done
}

CMD=$1
PKG=$2

[ -z "$1" ] && usage

root_req() {
	[ $(id -u) -eq 0 ] || fatal "root permissions needed"
}

has() {
	while [ ! -z "$1" ]; do
		[ -f "/usr/share/iglupkg/$1" ]
		shift
	done
}

iglupkg_check() {
	if ! command -v iglupkg > /dev/null 2>&1; then
		echo "iglupkg is missing??!!"
		exit 1
	fi
}


if [ "$CMD" = "add" ]; then
	root_req
	META_PATH=$(tar -I zstd -tf "$PKG" | grep 'usr/share/iglupkg/' | tail -n1)
	PKGNAME=$(basename "$META_PATH")

	TMP_DIR=$(mktemp -d)
	tar -I zstd -C "$TMP_DIR" -xf "$PKG" "$META_PATH"
	assert_deps "$TMP_DIR/$META_PATH"

	if [ -f "/$META_PATH" ]; then
		warn "package $PKGNAME already installed. upgrading ..."

		chop_fs "$TMP_DIR/$META_PATH" > "$TMP_DIR/new"
		chop_fs "/$META_PATH" > "$TMP_DIR/old"


		warn "removing duplicate files ..."
		TO_REMOVE=$(diff -u "$TMP_DIR/old" "$TMP_DIR/new" | grep -v '^---' | grep -E '^\-' | cut -d'-' -f2- | awk '{ print "/"$1 }')

		[ -z "$TO_REMOVE" ] || warn "will remove $TO_REMOVE"
		continue_interactive

		remove $TO_REMOVE
	else
		warn "installing $PKGNAME ..."
		continue_interactive
	fi
	tar -I zstd -C / -xf "$PKG"
	rm -rf "$TMP_DIR"
elif [ "$CMD" = "del" ]; then
	root_req
	META_PATH="/usr/share/iglupkg/$PKG"
	[ -f "$META_PATH" ] || fatal "package $PKG not installed"
	TO_REMOVE=$(chop_fs $META_PATH | awk '{ print "/"$1 }')
	[ -z "$TO_REMOVE" ] || warn "will remove $TO_REMOVE"
	continue_interactive

	remove $TO_REMOVE
elif [ "$CMD" =  "has" ]; then
	shift
	has $@
elif [  "$CMD" = "b"]; then
    #BUILD
	iglupkg_check
	iglupkg || exit 1
elif [ "$CMD" =  "ba" ]; then
    #BUILD INSTALL
	iglupkg_check
	iglupkg || exit 1
	cd out/
	for pkg in *.tar.xz; do
		iglu add "$pkg"
	done
else
	fatal "unknown command $CMD"
fi
