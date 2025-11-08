#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=usr/share/distiller-platform-update/lib/shared.sh
source "$(dirname "$SCRIPT_DIR")/lib/shared.sh"

readonly LOG_FILE="$LOG_DIR/platform-update.log"
CLAUDE_BIN="/usr/local/bin/claude"
REINSTALL_MODE=false

# Parse arguments
while [ $# -gt 0 ]; do
	case "$1" in
	--reinstall)
		REINSTALL_MODE=true
		shift
		;;
	*)
		shift
		;;
	esac
done

check_dependencies() {
	command -v npm &>/dev/null || {
		log_error "npm not installed (required for Claude Code installation)"
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

uninstall_claude_code() {
	if npm list -g @anthropic-ai/claude-code &>/dev/null; then
		log_success "Uninstalling existing Claude Code installation"
		npm uninstall -g --force @anthropic-ai/claude-code 2>&1 | tee -a "$LOG_FILE" || {
			log_error "Failed to uninstall Claude Code"
			return 1
		}
	fi
	return 0
}

install_claude_code() {
	log_success "Installing Claude Code via npm"
	npm install -g --force @anthropic-ai/claude-code 2>&1 | tee -a "$LOG_FILE" || {
		log_error "npm install failed"
		return 1
	}

	if [ -x "$CLAUDE_BIN" ] && "$CLAUDE_BIN" --version &>/dev/null; then
		log_success "Claude Code installation verified"
		return 0
	else
		log_error "Installation completed but verification failed"
		return 1
	fi
}

main() {
	check_dependencies || return 1

	if [ "$REINSTALL_MODE" = true ]; then
		uninstall_claude_code || return 1
		install_claude_code || return 1
	elif [ -x "$CLAUDE_BIN" ] && "$CLAUDE_BIN" --version &>/dev/null; then
		log_success "Claude Code already installed, skipping"
	else
		install_claude_code || return 1
	fi

	return 0
}

main
