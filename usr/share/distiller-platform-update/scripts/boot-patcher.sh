#!/bin/bash
set -e

BOOT_DIR="/boot/firmware"
BACKUP_DIR="/var/backups/distiller-platform-update/boot"
DATA_DIR="/usr/share/distiller-platform-update/data/boot"
MARKER_START="# Distiller CM5 Hardware Configuration"
MARKER_END="# End Distiller CM5 Hardware Configuration"

backup_boot() {
	mkdir -p "$BACKUP_DIR"
	local timestamp=$(date +%Y%m%d_%H%M%S)
	[ -f "$BOOT_DIR/cmdline.txt" ] && cp -a "$BOOT_DIR/cmdline.txt" "$BACKUP_DIR/cmdline.txt.$timestamp"
	[ -f "$BOOT_DIR/config.txt" ] && cp -a "$BOOT_DIR/config.txt" "$BACKUP_DIR/config.txt.$timestamp"
}

patch_cmdline() {
	[ ! -f "$BOOT_DIR/cmdline.txt" ] && {
		echo "ERROR: $BOOT_DIR/cmdline.txt not found" >&2
		return 1
	}

	local additions=$(cat "$DATA_DIR/cmdline.additions")
	[ "$(wc -l <"$BOOT_DIR/cmdline.txt")" -ne 1 ] && echo "WARNING: cmdline.txt has multiple lines" >&2

	if ! grep -qF "$additions" "$BOOT_DIR/cmdline.txt"; then
		echo "$(cat "$BOOT_DIR/cmdline.txt" | tr -d '\n') $additions" >"$BOOT_DIR/cmdline.txt"
	fi
}

extract_desired_directives() {
	grep -v '^#' "$1" | grep -v '^[[:space:]]*$' | sed 's/[[:space:]]*#.*$//; s/^[[:space:]]*//; s/[[:space:]]*$//'
}

find_duplicate_lines() {
	local config_file="$1" directive="$2" start_line="${3:-0}" end_line="${4:-0}"

	local search_pattern
	if [[ "$directive" =~ ^(dtoverlay|dtparam)= ]]; then
		search_pattern="^[[:space:]]*${directive}"
	elif [[ "$directive" =~ ^([^=]+)= ]]; then
		search_pattern="^[[:space:]]*${BASH_REMATCH[1]}="
	else
		search_pattern="^[[:space:]]*${directive}"
	fi

	grep -n "$search_pattern" "$config_file" 2>/dev/null | while IFS=: read -r line_num line_content; do
		[ "$start_line" -gt 0 ] && [ "$end_line" -gt 0 ] &&
			[ "$line_num" -ge "$start_line" ] && [ "$line_num" -le "$end_line" ] && continue
		echo "$line_num"
	done
}

comment_out_line() {
	local line_content=$(sed -n "${2}p" "$1")
	[[ "$line_content" =~ ^#\ \(Moved\ to\ Distiller\ section\) ]] && return 0
	sed -i "${2}s/^/# (Moved to Distiller section) /" "$1"
}

extract_distiller_block() {
	local start_line=$(grep -n "^${MARKER_START}" "$1" 2>/dev/null | head -1 | cut -d: -f1)
	[ -z "$start_line" ] && return

	local end_line=$(tail -n +"$start_line" "$1" | grep -n "^${MARKER_END}" 2>/dev/null | head -1 | cut -d: -f1)
	if [ -n "$end_line" ]; then
		echo "$start_line:$((start_line + end_line - 1))"
	else
		local next_section=$(tail -n +"$((start_line + 1))" "$1" | grep -n "^# Distiller\|^# Pamir" | head -1 | cut -d: -f1)
		[ -n "$next_section" ] && echo "$start_line:$((start_line + next_section - 1))" || echo "$start_line:$(wc -l <"$1")"
	fi
}

comment_out_duplicates() {
	local config_file="$1" additions_file="$2" start_line="${3:-0}" end_line="${4:-0}"
	local duplicates_found=0

	while IFS= read -r directive; do
		[ -z "$directive" ] && continue
		[[ "$directive" =~ ^\[.*\]$ ]] && continue

		while IFS= read -r dup_line; do
			[ -n "$dup_line" ] && comment_out_line "$config_file" "$dup_line" && duplicates_found=$((duplicates_found + 1))
		done < <(find_duplicate_lines "$config_file" "$directive" "$start_line" "$end_line")
	done < <(extract_desired_directives "$additions_file")

	[ "$duplicates_found" -gt 0 ] && echo "Commented out $duplicates_found duplicate directive(s)"
}

patch_config() {
	local config_file="$BOOT_DIR/config.txt" additions_file="$DATA_DIR/config.additions"
	[ ! -f "$config_file" ] && {
		echo "ERROR: $config_file not found" >&2
		return 1
	}

	local block_range=$(extract_distiller_block "$config_file")

	if [ -z "$block_range" ]; then
		comment_out_duplicates "$config_file" "$additions_file"
		{
			echo ""
			cat "$additions_file"
			echo "$MARKER_END"
		} >>"$config_file"
	else
		local start_line=$(echo "$block_range" | cut -d: -f1)
		local end_line=$(echo "$block_range" | cut -d: -f2)

		comment_out_duplicates "$config_file" "$additions_file" "$start_line" "$end_line"

		local before_block=$(head -n "$((start_line - 1))" "$config_file")
		local during_block=$(sed -n "${start_line},${end_line}p" "$config_file")
		local after_block=$(tail -n +"$((end_line + 1))" "$config_file")

		declare -A existing_directives
		local current_section=""

		while IFS= read -r line; do
			[[ "$line" =~ ^${MARKER_START}|^${MARKER_END}|^[[:space:]]*#|^[[:space:]]*$ ]] && continue

			if [[ "$line" =~ ^\[([^\]]+)\] ]]; then
				current_section="${BASH_REMATCH[1]}"
				continue
			fi

			local line_trimmed=$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
			if [[ "$line_trimmed" =~ ^([^=]+)= ]]; then
				local key="${BASH_REMATCH[1]}"
				[[ "$key" == "dtoverlay" || "$key" == "dtparam" ]] && key="$line_trimmed"
				[ -n "$current_section" ] && existing_directives["${current_section}:${key}"]="$line" || existing_directives["${key}"]="$line"
			fi
		done <<<"$during_block"

		local new_block="$MARKER_START"$'\n'
		current_section=""

		while IFS= read -r line; do
			[[ "$line" =~ ^[[:space:]]*# ]] && {
				new_block+="$line"$'\n'
				continue
			}

			if [[ "$line" =~ ^\[([^\]]+)\] ]]; then
				current_section="${BASH_REMATCH[1]}"
				new_block+="$line"$'\n'
				continue
			fi

			[[ "$line" =~ ^[[:space:]]*$ ]] && {
				new_block+="$line"$'\n'
				continue
			}

			local line_trimmed=$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
			if [[ "$line_trimmed" =~ ^([^=]+)= ]]; then
				local key="${BASH_REMATCH[1]}"
				[[ "$key" == "dtoverlay" || "$key" == "dtparam" ]] && key="$line_trimmed"

				local lookup_key
				[ -n "$current_section" ] && lookup_key="${current_section}:${key}" || lookup_key="${key}"

				if [ -n "${existing_directives[$lookup_key]}" ]; then
					new_block+="${existing_directives[$lookup_key]}"$'\n'
					unset "existing_directives[$lookup_key]"
				else
					new_block+="$line"$'\n'
				fi
			else
				new_block+="$line"$'\n'
			fi
		done <"$additions_file"

		[ "${#existing_directives[@]}" -gt 0 ] && {
			new_block+=$'\n# User customizations\n'
			for key in "${!existing_directives[@]}"; do
				new_block+="${existing_directives[$key]}"$'\n'
			done
		}

		new_block+="$MARKER_END"

		{
			echo "$before_block"
			echo "$new_block"
			echo "$after_block"
		} >"${config_file}.tmp"
		mv "${config_file}.tmp" "$config_file"
	fi
}

backup_boot
patch_cmdline
patch_config
