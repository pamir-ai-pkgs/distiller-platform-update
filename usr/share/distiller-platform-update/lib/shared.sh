#!/bin/bash

# Export constants for use in sourcing scripts
export PLATFORM_INFO="/etc/distiller-platform-info"
export DATA_DIR="/usr/share/distiller-platform-update/data"
export LIB_DIR="/usr/share/distiller-platform-update/lib"
export SCRIPTS_DIR="/usr/share/distiller-platform-update/scripts"
export BACKUP_DIR="/var/backups/distiller-platform-update"
export LOG_DIR="/var/log/distiller-platform-update"
export VERSION_FILE="/usr/share/distiller-platform-update/VERSION"
export UPDATE_THRESHOLD_VERSION="2.0.0"

# Mark as readonly after export
readonly PLATFORM_INFO DATA_DIR LIB_DIR SCRIPTS_DIR BACKUP_DIR LOG_DIR VERSION_FILE UPDATE_THRESHOLD_VERSION

log_error() {
	echo "[ERROR] $*" | tee -a "$LOG_DIR/platform-update.log" >&2
}

log_success() {
	echo "[SUCCESS] $*" | tee -a "$LOG_DIR/platform-update.log"
}

get_platform_version() {
	if [ ! -f "$PLATFORM_INFO" ]; then
		echo ""
		return
	fi
	# Returns version if found, or "0.0.0" if file exists but no version line present
	# This handles legacy images where /etc/distiller-platform-info exists without version
	grep "^DISTILLER_PLATFORM_VERSION=" "$PLATFORM_INFO" 2>/dev/null | cut -d= -f2 || echo "0.0.0"
}

update_platform_version() {
	local new_version="$1"
	if grep -q "^DISTILLER_PLATFORM_VERSION=" "$PLATFORM_INFO" 2>/dev/null; then
		local tmp_file
		tmp_file=$(mktemp) || {
			log_error "Cannot create temp file"
			return 1
		}
		trap 'rm -f "$tmp_file"' EXIT

		if ! sed "s/^DISTILLER_PLATFORM_VERSION=.*/DISTILLER_PLATFORM_VERSION=$new_version/" "$PLATFORM_INFO" >"$tmp_file"; then
			log_error "Cannot update platform version in $PLATFORM_INFO"
			return 1
		fi
		if ! mv "$tmp_file" "$PLATFORM_INFO"; then
			log_error "Cannot replace $PLATFORM_INFO"
			return 1
		fi
		chmod 644 "$PLATFORM_INFO"
		trap - EXIT
	else
		echo "DISTILLER_PLATFORM_VERSION=$new_version" >>"$PLATFORM_INFO"
		chmod 644 "$PLATFORM_INFO"
	fi
}

read_version_file() {
	[ -f "$VERSION_FILE" ] && cat "$VERSION_FILE"
}
