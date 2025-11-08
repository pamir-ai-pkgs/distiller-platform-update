#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=usr/share/distiller-platform-update/lib/shared.sh
source "$(dirname "$SCRIPT_DIR")/lib/shared.sh"

BOOT_DIR="/boot/firmware"
readonly BOOT_DATA_DIR="$DATA_DIR/boot"
readonly CONFIG_FILE="$BOOT_DIR/config.txt"
readonly ADDITIONS_FILE="$BOOT_DATA_DIR/config.additions"
readonly MARKER_START="# Distiller CM5 Hardware Configuration"
readonly MARKER_END="# End Distiller CM5 Hardware Configuration"

backup_boot() {
	mkdir -p "${BACKUP_DIR}/boot"
	local timestamp
	timestamp=$(date +%Y%m%d_%H%M%S)

	if [ -f "$BOOT_DIR/cmdline.txt" ]; then
		if ! cp -a "$BOOT_DIR/cmdline.txt" "${BACKUP_DIR}/boot/cmdline.txt.$timestamp"; then
			log_error "Cannot backup cmdline.txt"
			return 1
		fi
	fi

	if [ -f "$CONFIG_FILE" ]; then
		if ! cp -a "$CONFIG_FILE" "${BACKUP_DIR}/boot/config.txt.$timestamp"; then
			log_error "Cannot backup config.txt"
			return 1
		fi
	fi
}

patch_cmdline() {
	[ ! -f "$BOOT_DIR/cmdline.txt" ] && {
		log_error "$BOOT_DIR/cmdline.txt not found"
		return 1
	}

	local additions
	additions=$(cat "$BOOT_DATA_DIR/cmdline.additions")
	[ "$(wc -l <"$BOOT_DIR/cmdline.txt")" -ne 1 ] && echo "WARNING: cmdline.txt has multiple lines" >&2

	if ! grep -qF "$additions" "$BOOT_DIR/cmdline.txt"; then
		echo "$(cat "$BOOT_DIR/cmdline.txt" | tr -d '\n') $additions" >"$BOOT_DIR/cmdline.txt"
	fi
}

# Remove deprecated settings with their comment blocks
remove_deprecated_settings() {
	local setting="$1"

	# Find and remove all occurrences (reverse order to avoid line shifts)
	local removed=0
	while IFS=: read -r line_num _; do
		# Find the start of the comment block above this setting
		local block_start
		block_start=$(find_comment_block_start "$line_num")

		# Delete entire block (from first comment to directive)
		for ((i = line_num; i >= block_start; i--)); do
			sed -i "${i}d" "$CONFIG_FILE"
			removed=$((removed + 1))
		done
	done < <(grep -n "^[[:space:]]*${setting}=" "$CONFIG_FILE" | tac)

	if [ "$removed" -gt 0 ]; then
		log_success "Removed $removed line(s) including deprecated setting: $setting"
	fi
}

# Find the start of a comment block above a directive
find_comment_block_start() {
	local directive_line="$1"
	local current_line=$((directive_line - 1))
	local block_start="$directive_line"

	# Scan backwards for contiguous comments/empty lines
	while [ "$current_line" -ge 1 ]; do
		local line_content
		line_content=$(sed -n "${current_line}p" "$CONFIG_FILE")

		# Check if line is comment or empty
		if [[ "$line_content" =~ ^[[:space:]]*# ]] || [[ "$line_content" =~ ^[[:space:]]*$ ]]; then
			block_start="$current_line"
			current_line=$((current_line - 1))
		else
			# Hit non-comment, stop scanning
			break
		fi
	done

	echo "$block_start"
}

# Delete duplicate directives outside the Distiller block
delete_duplicates_outside_block() {
	local start_line="$1"
	local end_line="$2"

	# Extract directives from template (non-comment, non-empty lines)
	local directives
	directives=$(grep -v '^#' "$ADDITIONS_FILE" | grep -v '^[[:space:]]*$' | sed 's/[[:space:]]*#.*$//; s/^[[:space:]]*//; s/[[:space:]]*$//')

	local duplicates_found=0

	while IFS= read -r directive; do
		[ -z "$directive" ] && continue
		[[ "$directive" =~ ^\[.*\]$ ]] && continue

		# For dtoverlay/dtparam, match exactly; for other settings, match the key
		local key
		local grep_pattern
		if [[ "$directive" =~ ^(dtoverlay|dtparam)= ]]; then
			key="$directive"
			grep_pattern="^[[:space:]]*${key}"
		elif [[ "$directive" =~ ^([^=]+)= ]]; then
			key="${BASH_REMATCH[1]}"
			grep_pattern="^[[:space:]]*${key}="
		else
			continue
		fi

		# Find all matching lines
		local line_num
		while IFS=: read -r line_num _; do
			# Skip if within Distiller block range
			if [ "$start_line" -gt 0 ] && [ "$end_line" -gt 0 ]; then
				[ "$line_num" -ge "$start_line" ] && [ "$line_num" -le "$end_line" ] && continue
			fi

			# Find the start of the comment block
			local block_start
			block_start=$(find_comment_block_start "$line_num")

			# Delete entire block (from first comment to directive)
			for ((i = line_num; i >= block_start; i--)); do
				sed -i "${i}d" "$CONFIG_FILE"
				duplicates_found=$((duplicates_found + 1))
			done

			# Adjust end_line for all deleted lines
			local deleted_lines=$((line_num - block_start + 1))
			if [ "$end_line" -gt 0 ] && [ "$block_start" -lt "$end_line" ]; then
				end_line=$((end_line - deleted_lines))
			fi

			log_success "Deleted block (lines $block_start-$line_num): $directive"
		done < <(grep -n "$grep_pattern" "$CONFIG_FILE" | tac)

	done <<<"$directives"

	if [ "$duplicates_found" -gt 0 ]; then
		log_success "Deleted $duplicates_found duplicate directive(s)"
	fi
}

# Find first section marker
find_first_section_marker() {
	# Section markers are lines matching pattern [...]
	grep -n '^\[[^]]\+\]' "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d: -f1
}

# Extract line range of existing Distiller block
extract_distiller_block_range() {
	local start_line
	start_line=$(grep -n "^${MARKER_START}" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d: -f1)
	[ -z "$start_line" ] && return 1

	local end_line
	end_line=$(tail -n +"$start_line" "$CONFIG_FILE" | grep -n "^${MARKER_END}" 2>/dev/null | head -1 | cut -d: -f1)
	if [ -n "$end_line" ]; then
		echo "$start_line:$((start_line + end_line - 1))"
		return 0
	fi

	# No end marker - block is malformed, treat as no block
	return 1
}

# Insert new Distiller block
insert_distiller_block() {
	local first_section_line
	first_section_line=$(find_first_section_marker)

	local new_block
	new_block=$'\n'"$MARKER_START"$'\n'
	new_block+=$(cat "$ADDITIONS_FILE")
	new_block+=$'\n'"$MARKER_END"$'\n'

	if [ -n "$first_section_line" ]; then
		# Insert before first section marker (global scope)
		local marker_content
		marker_content=$(sed -n "${first_section_line}p" "$CONFIG_FILE")
		log_success "Inserting Distiller block before section marker '$marker_content' at line $first_section_line"

		local tmp_file
		tmp_file=$(mktemp) || {
			log_error "Cannot create temp file"
			return 1
		}
		trap 'rm -f "$tmp_file"' RETURN

		head -n "$((first_section_line - 1))" "$CONFIG_FILE" >"$tmp_file"
		echo "$new_block" >>"$tmp_file"
		tail -n "+${first_section_line}" "$CONFIG_FILE" >>"$tmp_file"

		if ! mv "$tmp_file" "$CONFIG_FILE"; then
			log_error "Cannot replace $CONFIG_FILE"
			return 1
		fi
		chmod 644 "$CONFIG_FILE"
		trap - RETURN
	else
		# No section markers - append to end
		log_success "No section markers found - appending Distiller block to end"
		echo "$new_block" >>"$CONFIG_FILE"
	fi
}

# Update existing Distiller block (simple replacement)
update_distiller_block() {
	local start_line="$1"
	local end_line="$2"

	log_success "Updating existing Distiller block (lines $start_line-$end_line)"

	# Extract before, during (for user customizations), and after
	local before_block
	before_block=$(head -n "$((start_line - 1))" "$CONFIG_FILE")
	local during_block
	during_block=$(sed -n "${start_line},${end_line}p" "$CONFIG_FILE")
	local after_block
	after_block=$(tail -n +"$((end_line + 1))" "$CONFIG_FILE")

	# Extract user customizations (lines not in template, excluding markers and comments)
	local user_customizations=""
	local template_lines
	template_lines=$(grep -v '^#' "$ADDITIONS_FILE" | grep -v '^[[:space:]]*$')

	while IFS= read -r line; do
		# Skip markers, comments, empty lines
		[[ "$line" =~ ^${MARKER_START}|^${MARKER_END}|^[[:space:]]*#|^[[:space:]]*$ ]] && continue

		# Check if line is in template
		if ! grep -qF "$line" <<<"$template_lines"; then
			user_customizations+="$line"$'\n'
		fi
	done <<<"$during_block"

	# Build new block
	local new_block=$'\n'"$MARKER_START"$'\n'
	new_block+=$(cat "$ADDITIONS_FILE")
	new_block+=$'\n'
	if [ -n "$user_customizations" ]; then
		new_block+=$'\n'"# User customizations"$'\n'
		new_block+="$user_customizations"
		new_block+=$'\n'
	fi
	new_block+="$MARKER_END"$'\n'

	# Write new config
	local tmp_file
	tmp_file=$(mktemp) || {
		log_error "Cannot create temp file"
		return 1
	}
	trap 'rm -f "$tmp_file"' RETURN

	{
		printf '%s\n' "$before_block"
		printf '%s' "$new_block"
		[ -n "$after_block" ] && printf '%s' "$after_block"
	} >"$tmp_file"

	if [ ! -s "$tmp_file" ]; then
		log_error "Generated empty config file"
		return 1
	fi

	if ! mv "$tmp_file" "$CONFIG_FILE"; then
		log_error "Cannot replace $CONFIG_FILE"
		return 1
	fi
	chmod 644 "$CONFIG_FILE"
	trap - RETURN
}

patch_config() {
	[ ! -f "$CONFIG_FILE" ] && {
		log_error "$CONFIG_FILE not found"
		return 1
	}

	# Try to extract existing block
	local block_range
	if block_range=$(extract_distiller_block_range); then
		# Block exists - delete duplicates and update
		local start_line end_line
		start_line=$(echo "$block_range" | cut -d: -f1)
		end_line=$(echo "$block_range" | cut -d: -f2)

		delete_duplicates_outside_block "$start_line" "$end_line"
		update_distiller_block "$start_line" "$end_line"
	else
		# No block - insert new block first, then delete duplicates
		insert_distiller_block

		# Now extract the newly inserted block's range and delete duplicates
		if block_range=$(extract_distiller_block_range); then
			start_line=$(echo "$block_range" | cut -d: -f1)
			end_line=$(echo "$block_range" | cut -d: -f2)
			delete_duplicates_outside_block "$start_line" "$end_line"
		fi
	fi
}

# Main execution
backup_boot
patch_cmdline
remove_deprecated_settings "over_voltage"
patch_config

log_success "Boot configuration patched successfully"
exit 0
