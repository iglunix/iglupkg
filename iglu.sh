#!/bin/sh -e
# usage: iglu [ add | del | has ] <pkg>

fatal() {
	printf "ERROR: %s\n" "$@"
	exit 1
}

warn() {
	printf "WARNING: %s\n" "$@"
}

usage() {
	if [ ! -z "$1" ]; then
		fatal "$@"
	fi
	printf "usage: %s [add | del | has] <pkg>\n" $(basename "$0")
	printf "version: 0.3.0\n"
	exit 1
}

if [ -z "$1" ]
then
	usage
fi

case "$1" in
	add)
		case "$2" in
			*.xbps)
				REPO=/var/lib/iglu
				cp "$2" "$REPO"
				cd "$REPO"
				rm -f *-repodata
				xbps-rindex -a *.xbps
				cd -
				b_name=$(basename "$2" | cut -d'.' -f1 | rev | cut -d'-' -f2- | rev)
				xbps-install --repository="$REPO" "$b_name" -f
				;;
			*)
				xbps-install "$2"
				;;
		esac
		;;
	del)
		xbps-remove -R "$2"
		;;
	has)
		xbps-query "$2"
		;;
	*)
		usage "unknown sub command: $1"
		;;
esac
