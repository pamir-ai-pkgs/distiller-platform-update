#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=usr/share/distiller-platform-update/lib/shared.sh
source "$(dirname "$SCRIPT_DIR")/lib/shared.sh"
[ "$EUID" -ne 0 ] && {
	echo "Must run as root" >&2
	exit 1
}

mkdir -p /etc/polkit-1/localauthority/50-local.d
shopt -s nullglob
for file in "$DATA_DIR/polkit-1/"*.pkla; do
	cp "$file" /etc/polkit-1/localauthority/50-local.d/
done
shopt -u nullglob
systemctl enable udisks2 2>/dev/null || true
systemctl restart udisks2 2>/dev/null || true

exit 0
