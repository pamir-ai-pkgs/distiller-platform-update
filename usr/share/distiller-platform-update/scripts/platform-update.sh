#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=usr/share/distiller-platform-update/lib/shared.sh
source "$(dirname "$SCRIPT_DIR")/lib/shared.sh"

# Remove legacy DISTILLER_PACKAGES_INSTALLED line from platform info
cleanup_legacy_package_list() {
	[ ! -f "$PLATFORM_INFO" ] && return 0

	if grep -q "^DISTILLER_PACKAGES_INSTALLED=" "$PLATFORM_INFO" 2>/dev/null; then
		local tmp_file
		tmp_file=$(mktemp) || {
			log_error "Cannot create temp file for platform info cleanup"
			return 1
		}
		trap 'rm -f "$tmp_file"' RETURN

		# Remove the DISTILLER_PACKAGES_INSTALLED line
		grep -v "^DISTILLER_PACKAGES_INSTALLED=" "$PLATFORM_INFO" >"$tmp_file"

		if ! mv "$tmp_file" "$PLATFORM_INFO"; then
			log_error "Cannot update $PLATFORM_INFO"
			return 1
		fi

		log_success "Removed legacy DISTILLER_PACKAGES_INSTALLED from platform info"
		trap - RETURN
	fi

	return 0
}

cleanup_legacy_package_list
exit 0
