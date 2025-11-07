#!/bin/bash

readonly PLATFORM_INFO="/etc/distiller-platform-info"
readonly DATA_DIR="/usr/share/distiller-platform-update/data"
readonly LIB_DIR="/usr/share/distiller-platform-update/lib"
readonly SCRIPTS_DIR="/usr/share/distiller-platform-update/scripts"
readonly BACKUP_DIR="/var/backups/distiller-platform-update"
readonly LOG_DIR="/var/log/distiller-platform-update"
readonly VERSION_FILE="/usr/share/distiller-platform-update/VERSION"
readonly UPDATE_THRESHOLD_VERSION="2.0.0"

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

		if ! sed "s/^DISTILLER_PLATFORM_VERSION=.*/DISTILLER_PLATFORM_VERSION=$new_version/" "$PLATFORM_INFO" > "$tmp_file"; then
			log_error "Cannot update platform version in $PLATFORM_INFO"
			return 1
		fi
		if ! mv "$tmp_file" "$PLATFORM_INFO"; then
			log_error "Cannot replace $PLATFORM_INFO"
			return 1
		fi
		trap - EXIT
	else
		echo "DISTILLER_PLATFORM_VERSION=$new_version" >>"$PLATFORM_INFO"
	fi
}

read_version_file() {
	[ -f "$VERSION_FILE" ] && cat "$VERSION_FILE"
}
