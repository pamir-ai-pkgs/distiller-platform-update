#!/bin/bash
set -e

source /usr/share/distiller-platform-update/lib/shared.sh
[ "$EUID" -ne 0 ] && {
	echo "Must run as root" >&2
	exit 1
}

mkdir -p /etc/polkit-1/localauthority/50-local.d
cp "$DATA_DIR/polkit-1/"*.pkla /etc/polkit-1/localauthority/50-local.d/
systemctl enable udisks2 2>/dev/null || true
systemctl restart udisks2 2>/dev/null || true

exit 0
