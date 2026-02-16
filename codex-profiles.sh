#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

CODEX_DIR="${HOME}/.codex"
BASE_DIR="${HOME}/.codex-profiles"
PROFILES_DIR="${BASE_DIR}/profiles"
STATE_DIR="${BASE_DIR}/state"
CURRENT_FILE="${STATE_DIR}/current_profile"
BACKUPS_DIR="${BASE_DIR}/backups"
TMP_DIR="${BASE_DIR}/tmp"

FORCE=0
VERBOSE=0
AUTOSAVE_ENABLED=1

usage() {
	cat <<EOF
Usage:
  ${SCRIPT_NAME} add <name>         Create profile from current ~/.codex
  ${SCRIPT_NAME} save [name]        Save current ~/.codex into named/current profile
  ${SCRIPT_NAME} list               List available profiles
  ${SCRIPT_NAME} switch [--no-autosave] <name>
                                Restore profile into ~/.codex
  ${SCRIPT_NAME} current            Print active profile (if known)
  ${SCRIPT_NAME} help               Show this help

Options:
  --force      Allow overwrite without prompt
  --verbose    Print additional logs
  --no-autosave (switch only)
              Disable auto-save for one switch operation
  -h, --help   Show this help

Examples:
  ${SCRIPT_NAME} add work
  ${SCRIPT_NAME} save
  ${SCRIPT_NAME} save personal
  ${SCRIPT_NAME} list
  ${SCRIPT_NAME} switch work
  ${SCRIPT_NAME} switch --no-autosave personal
  ${SCRIPT_NAME} current

Environment:
  CODEX_PROFILES_AUTOSAVE=1|0
              Enable/disable switch auto-save (default: 1)
EOF
}

info() {
	printf '%s\n' "$*"
}

debug() {
	if [[ "$VERBOSE" -eq 1 ]]; then
		printf '[debug] %s\n' "$*"
	fi
}

err() {
	printf 'Error: %s\n' "$*" >&2
}

ensure_base_dirs() {
	mkdir -p "$PROFILES_DIR" "$STATE_DIR" "$BACKUPS_DIR" "$TMP_DIR"
}

validate_profile_name() {
	local name="$1"
	if [[ -z "$name" ]]; then
		err "Profile name cannot be empty."
		return 1
	fi

	if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
		err "Invalid profile name '$name'. Use only letters, numbers, dot, underscore, or dash."
		return 1
	fi
}

profile_path() {
	local name="$1"
	printf '%s\n' "${PROFILES_DIR}/${name}/codex"
}

require_codex_dir() {
	if [[ ! -d "$CODEX_DIR" ]]; then
		err "'${CODEX_DIR}' does not exist. Open Codex once or create it before running this command."
		return 1
	fi
}

read_current_profile() {
	if [[ -f "$CURRENT_FILE" ]]; then
		local name
		name="$(<"$CURRENT_FILE")"
		printf '%s\n' "$name"
		return 0
	fi
	return 1
}

write_current_profile() {
	local name="$1"
	printf '%s\n' "$name" >"$CURRENT_FILE"
}

configure_autosave_from_env() {
	local raw="${CODEX_PROFILES_AUTOSAVE:-1}"
	local normalized="${raw,,}"

	case "$normalized" in
	1 | true | yes | on)
		AUTOSAVE_ENABLED=1
		;;
	0 | false | no | off)
		AUTOSAVE_ENABLED=0
		;;
	*)
		err "Invalid CODEX_PROFILES_AUTOSAVE value '$raw'. Use one of: 1, 0, true, false, yes, no, on, off."
		return 1
		;;
	esac
}

confirm_overwrite() {
	local what="$1"

	if [[ "$FORCE" -eq 1 ]]; then
		return 0
	fi

	if [[ ! -t 0 ]]; then
		err "Refusing to overwrite ${what} in non-interactive mode. Re-run with --force."
		return 1
	fi

	local reply
	printf 'Overwrite %s? [y/N]: ' "$what" >&2
	read -r reply
	case "$reply" in
	y | Y | yes | YES)
		return 0
		;;
	*)
		err "Aborted."
		return 1
		;;
	esac
}

copy_dir_to_staging() {
	local src_dir="$1"
	local staging_dir="$2"

	mkdir -p "$staging_dir"
	cp -a "$src_dir/." "$staging_dir/"
}

replace_directory_from_source() {
	local src_dir="$1"
	local dest_dir="$2"
	local dest_parent
	dest_parent="$(dirname "$dest_dir")"

	local tmp_parent
	tmp_parent="$(mktemp -d "${TMP_DIR}/replace.XXXXXX")"
	local staged
	staged="${tmp_parent}/payload"

	copy_dir_to_staging "$src_dir" "$staged"

	if [[ -e "$dest_dir" || -L "$dest_dir" ]]; then
		rm -rf "$dest_dir"
	fi

	mkdir -p "$dest_parent"
	mv "$staged" "$dest_dir"
	rm -rf "$tmp_parent"
}

backup_current_codex() {
	local ts
	ts="$(date +"%Y-%m-%dT%H-%M-%S")"
	local backup_path="${BACKUPS_DIR}/${ts}.codex.bak"

	if [[ -d "$CODEX_DIR" ]]; then
		mkdir -p "$backup_path"
		cp -a "$CODEX_DIR/." "$backup_path/"
		printf '%s\n' "$backup_path"
		return 0
	fi

	printf '%s\n' ""
}

cmd_add() {
	local name="${1:-}"
	if [[ -z "$name" ]]; then
		err "Usage: ${SCRIPT_NAME} add <name>"
		return 1
	fi

	validate_profile_name "$name"
	require_codex_dir

	local dest
	dest="$(profile_path "$name")"

	if [[ -d "$dest" ]]; then
		confirm_overwrite "existing profile '$name'"
	fi

	debug "Saving current Codex state into profile '$name'"
	replace_directory_from_source "$CODEX_DIR" "$dest"

	write_current_profile "$name"
	info "Profile '$name' created and set as current."
}

cmd_save() {
	local target="${1:-}"

	if [[ -z "$target" ]]; then
		if ! target="$(read_current_profile)"; then
			err "No profile provided and no current profile is set. Use '${SCRIPT_NAME} save <name>'."
			return 1
		fi
	fi

	validate_profile_name "$target"
	require_codex_dir

	local dest
	dest="$(profile_path "$target")"

	if [[ ! -d "$dest" ]]; then
		err "Profile '$target' does not exist. Create it first with '${SCRIPT_NAME} add $target'."
		return 1
	fi

	confirm_overwrite "profile '$target'"

	debug "Updating profile '$target' from current Codex state"
	replace_directory_from_source "$CODEX_DIR" "$dest"
	info "Profile '$target' updated from current ~/.codex state."
}

cmd_list() {
	local current=""
	if current="$(read_current_profile 2>/dev/null)"; then
		:
	else
		current=""
	fi

	local names=()
	local d
	for d in "$PROFILES_DIR"/*; do
		if [[ -d "$d/codex" ]]; then
			names+=("$(basename "$d")")
		fi
	done

	if [[ ${#names[@]} -eq 0 ]]; then
		info "No profiles found. Create one with '${SCRIPT_NAME} add <name>'."
		return 0
	fi

	local sorted
	sorted="$(printf '%s\n' "${names[@]}" | sort)"

	info "Profiles:"
	local name
	while IFS= read -r name; do
		if [[ -n "$current" && "$name" == "$current" ]]; then
			printf '* %s (current)\n' "$name"
		else
			printf '  %s\n' "$name"
		fi
	done <<<"$sorted"
}

cmd_switch() {
	local disable_autosave=0
	local name=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--no-autosave)
			disable_autosave=1
			;;
		*)
			if [[ -n "$name" ]]; then
				err "Usage: ${SCRIPT_NAME} switch [--no-autosave] <name>"
				return 1
			fi
			name="$1"
			;;
		esac
		shift
	done

	if [[ -z "$name" ]]; then
		err "Usage: ${SCRIPT_NAME} switch [--no-autosave] <name>"
		return 1
	fi

	validate_profile_name "$name"

	local src
	src="$(profile_path "$name")"
	if [[ ! -d "$src" ]]; then
		err "Profile '$name' does not exist. Use '${SCRIPT_NAME} list' to see available profiles."
		return 1
	fi

	if [[ "$AUTOSAVE_ENABLED" -eq 1 && "$disable_autosave" -eq 0 ]]; then
		if [[ -d "$CODEX_DIR" ]]; then
			local current
			if current="$(read_current_profile 2>/dev/null)"; then
				if [[ "$current" != "$name" ]]; then
					local current_dest
					current_dest="$(profile_path "$current")"
					if [[ ! -d "$current_dest" ]]; then
						err "Current profile '$current' does not exist on disk, cannot auto-save before switch. Use '--no-autosave' to bypass once."
						return 1
					fi
					debug "Auto-saving current profile '$current' before switch"
					replace_directory_from_source "$CODEX_DIR" "$current_dest"
				fi
			fi
		fi
	fi

	local backup_path
	backup_path="$(backup_current_codex)"

	debug "Restoring profile '$name' into ${CODEX_DIR}"
	replace_directory_from_source "$src" "$CODEX_DIR"
	write_current_profile "$name"

	if [[ -n "$backup_path" ]]; then
		info "Switched to profile '$name'. Backup created at: $backup_path"
	else
		info "Switched to profile '$name'. No existing ~/.codex directory was present to back up."
	fi
}

cmd_current() {
	local name
	if ! name="$(read_current_profile)"; then
		info "none"
		info "No current profile set. Use '${SCRIPT_NAME} add <name>' or '${SCRIPT_NAME} switch <name>'."
		return 0
	fi

	if [[ ! -d "$(profile_path "$name")" ]]; then
		info "none"
		info "Current profile marker points to missing profile '$name'. Use '${SCRIPT_NAME} switch <name>' to repair."
		return 0
	fi

	info "$name"
}

parse_args() {
	local args=()
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--force)
			FORCE=1
			shift
			;;
		--verbose)
			VERBOSE=1
			shift
			;;
		-h | --help)
			args+=("help")
			shift
			;;
		*)
			args+=("$1")
			shift
			;;
		esac
	done

	if [[ ${#args[@]} -eq 0 ]]; then
		args+=("help")
	fi

	set -- "${args[@]}"
	COMMAND="$1"
	shift || true
	COMMAND_ARGS=("$@")
}

main() {
	ensure_base_dirs
	configure_autosave_from_env
	parse_args "$@"

	case "$COMMAND" in
	add)
		cmd_add "${COMMAND_ARGS[@]:-}"
		;;
	save)
		cmd_save "${COMMAND_ARGS[@]:-}"
		;;
	list)
		cmd_list
		;;
	switch)
		cmd_switch "${COMMAND_ARGS[@]:-}"
		;;
	current)
		cmd_current
		;;
	help)
		usage
		;;
	*)
		err "Unknown command: $COMMAND"
		usage
		return 1
		;;
	esac
}

main "$@"
