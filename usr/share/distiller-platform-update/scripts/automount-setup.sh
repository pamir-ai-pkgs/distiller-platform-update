#!/bin/bash
set -e

source /usr/share/distiller-platform-update/lib/shared.sh
[ "$EUID" -ne 0 ] && {
	echo "Must run as root" >&2
	exit 1
}

cp "$DATA_DIR/polkit-1/rules.d/"*.rules /etc/polkit-1/rules.d/
systemctl enable udisks2 2>/dev/null || true
systemctl restart udisks2 2>/dev/null || true

exit 0
