#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_PATH="${ROOT_DIR}/codex-profiles.sh"
TMP_HOME=""

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

assert_eq() {
	local actual="$1"
	local expected="$2"
	local message="$3"
	if [[ "$actual" != "$expected" ]]; then
		fail "${message} (expected: '${expected}', got: '${actual}')"
	fi
}

assert_file_content() {
	local file="$1"
	local expected="$2"
	local message="$3"

	[[ -f "$file" ]] || fail "${message} (missing file: $file)"
	local content
	content="$(<"$file")"
	assert_eq "$content" "$expected" "$message"
}

main() {
	[[ -x "$SCRIPT_PATH" ]] || fail "Script is not executable: $SCRIPT_PATH"

	TMP_HOME="$(mktemp -d)"
	trap 'if [[ -n "${TMP_HOME:-}" ]]; then rm -rf "$TMP_HOME"; fi' EXIT

	mkdir -p "$TMP_HOME/.codex"
	printf 'work-state\n' >"$TMP_HOME/.codex/state.txt"

	HOME="$TMP_HOME" bash "$SCRIPT_PATH" add work >/dev/null

	printf 'personal-state\n' >"$TMP_HOME/.codex/state.txt"
	HOME="$TMP_HOME" bash "$SCRIPT_PATH" add personal >/dev/null

	local list_after_add
	list_after_add="$(HOME="$TMP_HOME" bash "$SCRIPT_PATH" list)"
	[[ "$list_after_add" == *"* personal (current)"* ]] || fail "list should mark newly added profile as current"

	HOME="$TMP_HOME" bash "$SCRIPT_PATH" switch work >/dev/null
	assert_file_content "$TMP_HOME/.codex/state.txt" "work-state" "switch work restores work state"

	printf 'work-state-v2\n' >"$TMP_HOME/.codex/state.txt"
	HOME="$TMP_HOME" bash "$SCRIPT_PATH" --force save work >/dev/null

	HOME="$TMP_HOME" bash "$SCRIPT_PATH" switch personal >/dev/null
	assert_file_content "$TMP_HOME/.codex/state.txt" "personal-state" "switch personal restores personal state"

	HOME="$TMP_HOME" bash "$SCRIPT_PATH" switch work >/dev/null
	assert_file_content "$TMP_HOME/.codex/state.txt" "work-state-v2" "save work persists updated state"

	printf 'work-autosave-default\n' >"$TMP_HOME/.codex/state.txt"
	HOME="$TMP_HOME" bash "$SCRIPT_PATH" switch personal >/dev/null
	HOME="$TMP_HOME" bash "$SCRIPT_PATH" switch work >/dev/null
	assert_file_content "$TMP_HOME/.codex/state.txt" "work-autosave-default" "switch auto-saves current profile by default"

	printf 'work-no-autosave-once\n' >"$TMP_HOME/.codex/state.txt"
	HOME="$TMP_HOME" bash "$SCRIPT_PATH" switch --no-autosave personal >/dev/null
	HOME="$TMP_HOME" bash "$SCRIPT_PATH" switch work >/dev/null
	assert_file_content "$TMP_HOME/.codex/state.txt" "work-autosave-default" "switch --no-autosave skips one-time auto-save"

	printf 'work-env-disabled\n' >"$TMP_HOME/.codex/state.txt"
	HOME="$TMP_HOME" CODEX_PROFILES_AUTOSAVE=0 bash "$SCRIPT_PATH" switch personal >/dev/null
	HOME="$TMP_HOME" bash "$SCRIPT_PATH" switch work >/dev/null
	assert_file_content "$TMP_HOME/.codex/state.txt" "work-autosave-default" "CODEX_PROFILES_AUTOSAVE=0 disables auto-save"

	local list_out
	list_out="$(HOME="$TMP_HOME" bash "$SCRIPT_PATH" list)"
	[[ "$list_out" == *"personal"* ]] || fail "list output missing personal profile"
	[[ "$list_out" == *"work"* ]] || fail "list output missing work profile"
	[[ "$list_out" == *"(current)"* ]] || fail "list output missing current marker"

	local current_out
	current_out="$(HOME="$TMP_HOME" bash "$SCRIPT_PATH" current)"
	assert_eq "$current_out" "work" "current reports active profile"

	if ! HOME="$TMP_HOME" bash "$SCRIPT_PATH" add "bad/name" >/dev/null 2>&1; then
		:
	else
		fail "invalid profile name should fail"
	fi

	local backup_count
	backup_count="$(ls -1 "$TMP_HOME/.codex-profiles/backups" | wc -l | tr -d ' ')"
	if [[ "$backup_count" -lt 1 ]]; then
		fail "expected at least one backup after switch operations"
	fi

	printf 'PASS: smoke tests completed successfully\n'
}

main "$@"
