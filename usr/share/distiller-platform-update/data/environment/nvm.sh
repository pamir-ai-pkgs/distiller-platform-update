#!/bin/bash
# NVM initialization for system-wide access
# Installed by distiller-platform-update

# Default to distiller user's NVM installation
NVM_DIR="${NVM_DIR:-/home/distiller/.nvm}"

# Load NVM if available
if [ -s "$NVM_DIR/nvm.sh" ]; then
	# shellcheck source=/dev/null
	\. "$NVM_DIR/nvm.sh"
fi

# Load NVM bash completion if available
if [ -s "$NVM_DIR/bash_completion" ]; then
	# shellcheck source=/dev/null
	\. "$NVM_DIR/bash_completion"
fi
