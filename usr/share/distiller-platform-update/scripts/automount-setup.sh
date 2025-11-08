#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=usr/share/distiller-platform-update/lib/shared.sh
source "$(dirname "$SCRIPT_DIR")/lib/shared.sh"
[ "$EUID" -ne 0 ] && {
	echo "Must run as root" >&2
	exit 1
}

# Create PolicyKit directory with error checking
if ! mkdir -p /etc/polkit-1/localauthority/50-local.d; then
	log_error "Failed to create /etc/polkit-1/localauthority/50-local.d"
	exit 1
fi

# Verify source directory exists
if [ ! -d "$DATA_DIR/polkit-1" ]; then
	log_error "Source directory not found: $DATA_DIR/polkit-1"
	exit 1
fi

# Copy PolicyKit files with error checking
shopt -s nullglob
files_copied=0
for file in "$DATA_DIR/polkit-1/"*.pkla; do
	if ! cp "$file" /etc/polkit-1/localauthority/50-local.d/; then
		log_error "Failed to copy $(basename "$file") to /etc/polkit-1/localauthority/50-local.d/"
		exit 1
	fi
	log_success "Installed PolicyKit rule: $(basename "$file")"
	files_copied=$((files_copied + 1))
done
shopt -u nullglob

# Verify at least one file was copied
if [ "$files_copied" -eq 0 ]; then
	log_error "No PolicyKit .pkla files found in $DATA_DIR/polkit-1/"
	exit 1
fi

systemctl enable udisks2 2>/dev/null || true
systemctl restart udisks2 2>/dev/null || true

exit 0
