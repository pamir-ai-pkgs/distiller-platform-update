#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=usr/share/distiller-platform-update/lib/shared.sh
source "$(dirname "$SCRIPT_DIR")/lib/shared.sh"

TARGET_USER="${1:-distiller}"
NODE_VERSION="20.19.5"
NVM_VERSION="v0.40.1"
NVM_URL="https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"

# Exit gracefully if user doesn't exist
id "$TARGET_USER" &>/dev/null || exit 0

# Install NVM for the target user
if ! su - "$TARGET_USER" -c "curl -o- $NVM_URL | bash" &>/dev/null; then
	log_error "NVM installation failed"
	exit 0
fi

# Install Node.js via NVM
# shellcheck disable=SC2016  # Single quotes intentional - command runs in su context where $HOME expands
install_cmd='export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && nvm install '"$NODE_VERSION"' && nvm alias default '"$NODE_VERSION"

if ! su - "$TARGET_USER" -c "$install_cmd" &>/dev/null; then
	log_error "Node.js installation failed"
	exit 0
fi

# Install system-wide NVM profile script
mkdir -p /etc/profile.d
if [ -f "$DATA_DIR/environment/nvm.sh" ]; then
	cp "$DATA_DIR/environment/nvm.sh" /etc/profile.d/nvm.sh
	chmod 644 /etc/profile.d/nvm.sh
	log_success "Installed NVM profile script to /etc/profile.d/nvm.sh"
fi

exit 0
