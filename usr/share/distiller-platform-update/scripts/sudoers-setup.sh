#!/bin/bash
set -e

source /usr/share/distiller-platform-update/lib/shared.sh
[ "$EUID" -ne 0 ] && {
	echo "Must run as root" >&2
	exit 1
}

# Copy sudoers files from data directory to /etc/sudoers.d/
cp "$DATA_DIR/sudoers.d/"* /etc/sudoers.d/

# Set correct permissions and ownership
chown root:root /etc/sudoers.d/10-distiller-hardware
chmod 0440 /etc/sudoers.d/10-distiller-hardware

# Validate syntax
if visudo -c -f /etc/sudoers.d/10-distiller-hardware >/dev/null 2>&1; then
	log_success "Sudoers file configured successfully"
else
	log_error "Sudoers file has syntax errors"
fi

exit 0
