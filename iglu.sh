#!/bin/sh -e
# usage: iglu [ add | del | has ] <pkg>
#
# options:
#  -a <arch> target arch
#  -r <dir> root dir

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
		shift
		root_dir=
		yes=
		name=
		xbps_arch=
		while :
		do
			case "$1" in
				-a)
					shift
					if [ ! -z "$1" ]
					then
						xbps_arch="$1"
					else
						fatal '-a requires an argument'
					fi
					shift
					;;
				-r)
					shift
					if [ ! -z "$1" ]
					then
						root_dir="$1"
					else
						fatal '-r requires an argument'
					fi
					shift
					;;
				-y)
					yes=1
					shift
					;;
				*)
					if [ ! -z "$1" ]
					then
						name="$1"
						shift
					else
						break
					fi
			esac
		done
		xbps_extra_args=
		if [ ! -z "$root_dir" ]
		then
			xbps_extra_args="-r $root_dir $xbps_extra_args"
		fi

		if [ ! -z "$yes" ]
		then
			xbps_extra_args="-y $xbps_extra_args"
		fi

		if [ ! -z "$xbps_arch" ]
		then
			export XBPS_ARCH="$xbps_arch"
			export XBPS_TARGET_ARCH="$xbps_arch"
		fi

		case "$name" in
			*.xbps)
				REPO=/run/iglu
				mkdir -p $REPO
				cp "$name" "$REPO"
				cd "$REPO"
				rm -f *-repodata
				xbps-rindex -a *.xbps
				cd -
				b_name=$(basename "$name" | cut -d'.' -f1 | rev | cut -d'-' -f2- | rev)
				xbps-install $xbps_extra_args --repository="$REPO" "$b_name" -f
				rm -rf $REPO
				;;
			*)
				xbps-install "$name"
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
