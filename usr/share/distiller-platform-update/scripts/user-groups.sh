#!/bin/bash
set -e

TARGET_USER="${1:-distiller}"
REQUIRED_GROUPS="netdev,input,i2c,spi,dialout,gpio,audio,video"

# Exit silently if user doesn't exist
id "$TARGET_USER" &>/dev/null || exit 0

# Add user to groups (ignore errors if some groups don't exist)
usermod -aG "$REQUIRED_GROUPS" "$TARGET_USER" 2>/dev/null || true

exit 0
