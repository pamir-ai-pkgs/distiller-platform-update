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
	# Update existing value atomically
	tmp_file=$(mktemp) || {
		echo "ERROR: Cannot create temp file" >&2
		exit 1
	}
	trap 'rm -f "$tmp_file"' EXIT

	if ! sed "s/^DISTILLER_PLATFORM=.*/DISTILLER_PLATFORM=$platform/" /etc/environment > "$tmp_file"; then
		echo "ERROR: Cannot update DISTILLER_PLATFORM in /etc/environment" >&2
		exit 1
	fi
	if ! mv "$tmp_file" /etc/environment; then
		echo "ERROR: Cannot replace /etc/environment" >&2
		exit 1
	fi
	chmod 644 /etc/environment
	trap - EXIT
else
	# Append new value
	echo "DISTILLER_PLATFORM=$platform" >> /etc/environment
fi

if grep -q "/opt/distiller-cm5-sdk" /etc/environment 2>/dev/null; then
	# Create backup directory and backup before migration
	mkdir -p "$BACKUP_DIR"
	backup_file="${BACKUP_DIR}/environment.$(date +%Y%m%d_%H%M%S)"
	if ! cp /etc/environment "$backup_file"; then
		echo "ERROR: Cannot backup /etc/environment to $backup_file" >&2
		exit 1
	fi

	# Use atomic write for migration
	tmp_file=$(mktemp) || {
		echo "ERROR: Cannot create temp file" >&2
		exit 1
	}
	trap 'rm -f "$tmp_file"' EXIT

	if ! sed 's|/opt/distiller-cm5-sdk|/opt/distiller-sdk|g' /etc/environment > "$tmp_file"; then
		echo "ERROR: Cannot migrate SDK paths in /etc/environment" >&2
		exit 1
	fi
	if ! mv "$tmp_file" /etc/environment; then
		echo "ERROR: Cannot replace /etc/environment" >&2
		exit 1
	fi
	chmod 644 /etc/environment
	trap - EXIT

	echo "Migrated legacy SDK paths in /etc/environment (backup: $backup_file)"
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
