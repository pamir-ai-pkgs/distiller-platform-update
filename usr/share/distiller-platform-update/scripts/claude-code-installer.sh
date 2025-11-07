#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/lib/shared.sh"

readonly LOG_FILE="$LOG_DIR/platform-update.log"
INSTALL_SCRIPT_URL="https://claude.ai/install.sh"
CLAUDE_BIN="/usr/local/bin/claude"

check_dependencies() {
	command -v curl &>/dev/null || {
		log_error "curl not installed"
		return 1
	}
	command -v node &>/dev/null || {
		log_error "Node.js not installed (Claude Code requires Node.js 18+)"
		return 1
	}

	local node_version
	node_version=$(node --version | sed 's/v//' | cut -d'.' -f1)
	[ "$node_version" -ge 18 ] || {
		log_error "Node.js $node_version too old (requires 18+)"
		return 1
	}
}

install_claude_code() {
	curl --retry 3 --retry-delay 5 -fsSL "$INSTALL_SCRIPT_URL" -o /tmp/claude-install.sh 2>&1 | tee -a "$LOG_FILE" || {
		log_error "Failed to download installer"
		return 1
	}

	chmod +x /tmp/claude-install.sh
	bash /tmp/claude-install.sh 2>&1 | tee -a "$LOG_FILE" || {
		log_error "Installer failed"
		rm -f /tmp/claude-install.sh
		return 1
	}

	rm -f /tmp/claude-install.sh

	[ -x "$CLAUDE_BIN" ] && "$CLAUDE_BIN" --version &>/dev/null || {
		log_error "Installation completed but verification failed"
		return 1
	}
}

update_claude_code() {
	[ -x "$CLAUDE_BIN" ] || return 1
	"$CLAUDE_BIN" update 2>&1 | tee -a "$LOG_FILE" || true
}

main() {
	check_dependencies || return 1

	if [ -x "$CLAUDE_BIN" ] && "$CLAUDE_BIN" --version &>/dev/null; then
		update_claude_code
	else
		install_claude_code || return 1
	fi

	return 0
}

main "$@"
