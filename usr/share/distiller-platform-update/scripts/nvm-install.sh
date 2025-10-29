#!/bin/bash

source /usr/share/distiller-platform-update/lib/shared.sh

TARGET_USER="${1:-distiller}"
NODE_VERSION="20.19.5"
NVM_VERSION="v0.40.1"
NVM_URL="https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"

id "$TARGET_USER" &>/dev/null || exit 0

if ! su - "$TARGET_USER" -c "curl -o- $NVM_URL | bash" &>/dev/null; then
	log_error "NVM installation failed"
	exit 0
fi

install_cmd='export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && nvm install '"$NODE_VERSION"' && nvm alias default '"$NODE_VERSION"

if ! su - "$TARGET_USER" -c "$install_cmd" &>/dev/null; then
	log_error "Node.js installation failed"
	exit 0
fi

exit 0
