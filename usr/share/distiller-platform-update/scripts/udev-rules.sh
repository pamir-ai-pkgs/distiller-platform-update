#!/bin/bash
set -e

source /usr/share/distiller-platform-update/lib/shared.sh
[ "$EUID" -ne 0 ] && {
	echo "Must run as root" >&2
	exit 1
}

shopt -s nullglob
for file in "$DATA_DIR/udev/rules.d/"*.rules; do
	cp "$file" /etc/udev/rules.d/
done
shopt -u nullglob
udevadm control --reload-rules
udevadm trigger

exit 0
