#!/bin/bash
set -e

source /usr/share/distiller-platform-update/lib/shared.sh
[ "$EUID" -ne 0 ] && {
	echo "Must run as root" >&2
	exit 1
}

cp "$DATA_DIR/logrotate.d/distiller" /etc/logrotate.d/

exit 0
