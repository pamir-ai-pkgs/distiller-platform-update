#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

[ "$EUID" -eq 0 ] || {
	log_error "Must run as root"
	exit 1
}

# Get versions
prev_version=$(get_platform_version)
new_version=$(read_version_file)

# Check if full update needed
requires_update() {
	local current="$1"
	local threshold="$2"

	# If current is empty (new install) or less than threshold
	[ "$current" = "" ] && return 0

	# Compare versions
	dpkg --compare-versions "$current" lt "$threshold" && return 0

	return 1
}

# Incremental update check (for existing v2.0.0 installs)
if ! requires_update "$prev_version" "$UPDATE_THRESHOLD_VERSION"; then
	# Check if Claude Code is installed
	if ! which claude &>/dev/null; then
		# Install profile script for PATH
		mkdir -p /etc/profile.d
		[ -f "$DATA_DIR/environment/claude-code-profile.sh" ] &&
			cp "$DATA_DIR/environment/claude-code-profile.sh" /etc/profile.d/ &&
			chmod 644 /etc/profile.d/claude-code-profile.sh

		# Install Claude Code
		"$SCRIPTS_DIR/claude-code-installer.sh" || true
	fi

	# Update version
	update_platform_version "$new_version"
	exit 0
fi

# Full update required - detect platform
platform=$("$LIB_DIR/platform-detect.sh")
export DISTILLER_PLATFORM="$platform"

# Run update phases
"$SCRIPTS_DIR/apt-repos.sh"
"$SCRIPTS_DIR/env-vars.sh" "$platform"
"$SCRIPTS_DIR/user-groups.sh" || true
"$SCRIPTS_DIR/udev-rules.sh"
"$SCRIPTS_DIR/sudoers-setup.sh"
"$SCRIPTS_DIR/automount-setup.sh"
"$SCRIPTS_DIR/logrotate-setup.sh" || true

# Boot patching (requires reboot)
if [ -d /boot/firmware ]; then
	"$SCRIPTS_DIR/boot-patcher.sh"
fi

# Developer tools (non-fatal)
"$SCRIPTS_DIR/nvm-install.sh" || true

# Claude Code (non-fatal) - already installed in incremental update path
[ ! -x /usr/local/bin/claude ] && "$SCRIPTS_DIR/claude-code-installer.sh" || true

# Update version
update_platform_version "$new_version"

exit 0
