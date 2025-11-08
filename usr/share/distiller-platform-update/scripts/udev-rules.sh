#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=usr/share/distiller-platform-update/lib/shared.sh
source "$(dirname "$SCRIPT_DIR")/lib/shared.sh"
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

log_success "Udev rules installed and reloaded"

exit 0
