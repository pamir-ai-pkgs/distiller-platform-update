#!/bin/bash
set -e

source /usr/share/distiller-platform-update/lib/shared.sh
[ "$EUID" -ne 0 ] && {
	echo "Must run as root" >&2
	exit 1
}

cp "$DATA_DIR/udev/rules.d/"*.rules /etc/udev/rules.d/
udevadm control --reload-rules
udevadm trigger

exit 0
