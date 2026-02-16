#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="${BIN_DIR:-${HOME}/.local/bin}"
TARGET_PATH="${BIN_DIR}/codex-profiles"

if [[ -e "$TARGET_PATH" || -L "$TARGET_PATH" ]]; then
	rm -f "$TARGET_PATH"
	printf 'Removed %s\n' "$TARGET_PATH"
else
	printf 'Nothing to remove at %s\n' "$TARGET_PATH"
fi
