#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=usr/share/distiller-platform-update/lib/shared.sh
source "$(dirname "$SCRIPT_DIR")/lib/shared.sh"

TARGET_USER="${1:-distiller}"
REQUIRED_GROUPS="netdev,input,i2c,spi,dialout,gpio,audio,video"

# Exit silently if user doesn't exist
id "$TARGET_USER" &>/dev/null || exit 0

# Add user to groups (ignore errors if some groups don't exist)
usermod -aG "$REQUIRED_GROUPS" "$TARGET_USER" 2>/dev/null || true

log_success "User groups configured for $TARGET_USER"

exit 0
