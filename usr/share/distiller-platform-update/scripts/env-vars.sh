#!/bin/bash
set -e

source /usr/share/distiller-platform-update/lib/shared.sh
[ "$EUID" -ne 0 ] && {
	echo "Must run as root" >&2
	exit 1
}

platform="${1:-$DISTILLER_PLATFORM}"
[ -n "$platform" ] || platform=$("$LIB_DIR/platform-detect.sh")

if grep -q "^DISTILLER_PLATFORM=" /etc/environment 2>/dev/null; then
	sed -i "s/^DISTILLER_PLATFORM=.*/DISTILLER_PLATFORM=$platform/" /etc/environment
else
	echo "DISTILLER_PLATFORM=$platform" >>/etc/environment
fi

if grep -q "/opt/distiller-cm5-sdk" /etc/environment 2>/dev/null; then
	mkdir -p /var/backups/distiller-platform-update
	cp /etc/environment /var/backups/distiller-platform-update/environment.$(date +%Y%m%d_%H%M%S)
	sed -i 's|/opt/distiller-cm5-sdk|/opt/distiller-sdk|g' /etc/environment
fi

while IFS= read -r line; do
	[ -z "$line" ] && continue
	[[ "$line" =~ ^[[:space:]]*# ]] && continue

	var_name=$(echo "$line" | cut -d= -f1)
	[ -z "$var_name" ] && continue

	grep -q "^$var_name=" /etc/environment 2>/dev/null && continue
	echo "$line" >>/etc/environment
done <"$DATA_DIR/environment/distiller-vars.env"

exit 0
