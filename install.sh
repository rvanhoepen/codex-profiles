#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_SCRIPT="${ROOT_DIR}/codex-profiles.sh"
BIN_DIR="${BIN_DIR:-${HOME}/.local/bin}"
TARGET_NAME="codex-profiles"
TARGET_PATH="${BIN_DIR}/${TARGET_NAME}"
ALIAS_NAME="cxp"
ALIAS_PATH="${BIN_DIR}/${ALIAS_NAME}"

warn() {
	printf 'Warning: %s\n' "$*" >&2
}

if [[ ! -f "$SRC_SCRIPT" ]]; then
	printf 'Error: missing source script at %s\n' "$SRC_SCRIPT" >&2
	exit 1
fi

mkdir -p "$BIN_DIR"
cp "$SRC_SCRIPT" "$TARGET_PATH"
chmod +x "$TARGET_PATH"

install_alias=1
if [[ -e "$ALIAS_PATH" || -L "$ALIAS_PATH" ]]; then
	if [[ -L "$ALIAS_PATH" ]]; then
		alias_target="$(readlink "$ALIAS_PATH" || true)"
		if [[ "$alias_target" != "$TARGET_PATH" ]]; then
			warn "'${ALIAS_PATH}' already exists and points to '${alias_target}'. Leaving it unchanged."
			warn "Remove it manually if you want this installer to manage the '${ALIAS_NAME}' alias."
			install_alias=0
		fi
	else
		warn "'${ALIAS_PATH}' already exists and is not a symlink. Leaving it unchanged."
		warn "Remove it manually if you want this installer to manage the '${ALIAS_NAME}' alias."
		install_alias=0
	fi
fi

if [[ "$install_alias" -eq 1 ]]; then
	ln -sfn "$TARGET_PATH" "$ALIAS_PATH"
fi

printf 'Installed %s\n' "$TARGET_PATH"
if [[ "$install_alias" -eq 1 ]]; then
	printf 'Installed %s -> %s\n' "$ALIAS_PATH" "$TARGET_PATH"
else
	printf 'Skipped alias install for %s\n' "$ALIAS_PATH"
fi
printf 'Run: %s help\n' "$TARGET_NAME"
printf 'Or:  %s help\n' "$ALIAS_NAME"
