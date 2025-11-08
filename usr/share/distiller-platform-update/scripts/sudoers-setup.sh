#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=usr/share/distiller-platform-update/lib/shared.sh
source "$(dirname "$SCRIPT_DIR")/lib/shared.sh"
[ "$EUID" -ne 0 ] && {
	echo "Must run as root" >&2
	exit 1
}

# Stage, validate, then install sudoers files (prevent security window)
tmp_dir=$(mktemp -d) || {
	log_error "Cannot create temp directory"
	exit 1
}
trap 'rm -rf "$tmp_dir"' EXIT

shopt -s nullglob
for file in "$DATA_DIR/sudoers.d/"*; do
	filename=$(basename "$file")
	cp "$file" "$tmp_dir/$filename"
	chown root:root "$tmp_dir/$filename"
	chmod 0440 "$tmp_dir/$filename"

	# Validate BEFORE installing to production
	if ! visudo -c -f "$tmp_dir/$filename" >/dev/null 2>&1; then
		log_error "Sudoers file $filename has syntax errors"
		exit 1
	fi

	# Only install if validation passed
	cp "$tmp_dir/$filename" /etc/sudoers.d/
done
shopt -u nullglob

trap - EXIT
rm -rf "$tmp_dir"
log_success "Sudoers file configured successfully"

exit 0
