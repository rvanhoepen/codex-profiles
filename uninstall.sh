#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="${BIN_DIR:-${HOME}/.local/bin}"
TARGET_PATH="${BIN_DIR}/codex-profiles"
ALIAS_PATH="${BIN_DIR}/cxp"

warn() {
	printf 'Warning: %s\n' "$*" >&2
}

if [[ -e "$TARGET_PATH" || -L "$TARGET_PATH" ]]; then
	rm -f "$TARGET_PATH"
	printf 'Removed %s\n' "$TARGET_PATH"
else
	printf 'Nothing to remove at %s\n' "$TARGET_PATH"
fi

if [[ -L "$ALIAS_PATH" ]]; then
	alias_target="$(readlink "$ALIAS_PATH" || true)"
	if [[ "$alias_target" == "$TARGET_PATH" ]]; then
		rm -f "$ALIAS_PATH"
		printf 'Removed %s\n' "$ALIAS_PATH"
	else
		warn "'${ALIAS_PATH}' points to '${alias_target}'. Leaving it unchanged."
	fi
elif [[ -e "$ALIAS_PATH" ]]; then
	warn "'${ALIAS_PATH}' exists and is not managed by this project. Leaving it unchanged."
else
	printf 'Nothing to remove at %s\n' "$ALIAS_PATH"
fi
