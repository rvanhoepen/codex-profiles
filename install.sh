#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_SCRIPT="${ROOT_DIR}/codex-profiles.sh"
BIN_DIR="${BIN_DIR:-${HOME}/.local/bin}"
TARGET_NAME="codex-profiles"
TARGET_PATH="${BIN_DIR}/${TARGET_NAME}"

if [[ ! -f "$SRC_SCRIPT" ]]; then
	printf 'Error: missing source script at %s\n' "$SRC_SCRIPT" >&2
	exit 1
fi

mkdir -p "$BIN_DIR"
cp "$SRC_SCRIPT" "$TARGET_PATH"
chmod +x "$TARGET_PATH"

printf 'Installed %s\n' "$TARGET_PATH"
printf 'Run: %s help\n' "$TARGET_NAME"
