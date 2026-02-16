# OpenSpec: Codex Profile Switching Script

## 1. Context

Codex currently does not support signing into multiple accounts (for example, `work` and `personal`) in a single install flow. At the same time, Codex stores local state under `~/.codex/*`.

This spec defines a Bash-based profile manager that snapshots and restores `~/.codex` so users can quickly switch between named profiles.

## 2. Problem Statement

Users need a safe, repeatable way to:

- create a named profile,
- save current Codex state into that profile,
- list available profiles,
- switch from one profile to another.

Without tooling, switching requires manual file copying in `~/.codex`, which is error-prone and can lead to accidental data loss.

## 3. Goals

- Provide a single script to manage Codex profiles via CLI commands.
- Treat `~/.codex` as the source state to snapshot/restore.
- Prevent destructive actions by default (backups, validation, confirmation where needed).
- Keep implementation dependency-light (POSIX/Bash + standard Unix utilities).

## 4. Non-Goals

- Managing remote authentication or Codex server-side account behavior.
- Merging profile contents.
- Cross-machine profile sync.
- GUI/TUI experience in the initial version.

## 5. Requirements

### Functional Requirements

- **FR-001**: The tool MUST support `add <profile>` to create a profile from current `~/.codex` state.
- **FR-002**: The tool MUST support `save [profile]` to overwrite a profile with current `~/.codex` state.
- **FR-003**: The tool MUST support `list` to show available profiles.
- **FR-004**: The tool MUST support `switch <profile>` to replace active `~/.codex` with selected profile contents.
- **FR-005**: The tool MUST show the currently active profile (directly or inferentially).
- **FR-006**: The tool MUST fail with clear errors for missing/invalid profile names.
- **FR-007**: The tool MUST create required directories if missing.
- **FR-008**: `add <profile>` MUST set `current_profile` to the newly added profile so `list`/`current` update immediately.

### Safety Requirements

- **SR-001**: The tool MUST back up current `~/.codex` before switching.
- **SR-002**: The tool MUST avoid partial writes (stage then move atomically where possible).
- **SR-003**: The tool MUST refuse destructive overwrite unless user explicitly requests it (or uses a forced flag).

### UX Requirements

- **UX-001**: Commands MUST print short success/failure messages.
- **UX-002**: `help` output MUST document all commands and examples.
- **UX-003**: Exit codes MUST follow Unix conventions (`0` success, non-zero failure).

## 6. Proposed CLI

Script name: `codex-profiles.sh`

```bash
codex-profiles.sh add <name>         # create profile from current ~/.codex
codex-profiles.sh save [name]        # save current ~/.codex into named/current profile
codex-profiles.sh list               # list all profiles
codex-profiles.sh switch <name>      # restore profile into ~/.codex
codex-profiles.sh current            # print active profile (if known)
codex-profiles.sh help
```

Optional flags (v1 if time allows):

- `--force` to allow overwrite without prompt.
- `--verbose` for debug output.

## 7. Data Model and Filesystem Layout

Base directory: `~/.codex-profiles`

```text
~/.codex-profiles/
  profiles/
    work/
      codex/            # snapshot of ~/.codex
    personal/
      codex/
  state/
    current_profile     # plain text: active profile name
  backups/
    2026-02-16T12-34-56.codex.bak/
```

Rules:

- Profile names match: `^[a-zA-Z0-9._-]+$`
- Paths are always quoted in shell operations.
- Temporary writes use a staging directory, then rename/move.

## 8. Command Behavior Spec

### `add <name>`

1. Validate name.
2. Ensure `~/.codex` exists (or initialize empty snapshot policy).
3. If profile exists, fail unless `--force`.
4. Copy `~/.codex` to `~/.codex-profiles/profiles/<name>/codex`.
5. Set `current_profile` to `<name>`.

### `save [name]`

1. Resolve target profile:
   - explicit `[name]`, else
   - `current_profile`, else fail with guidance.
2. Validate target exists (or allow creation if `--create` in future).
3. Snapshot current `~/.codex` into the profile path.

### `list`

1. Enumerate `~/.codex-profiles/profiles/*`.
2. Mark active profile from `current_profile`.
3. Print deterministic sorted output.

### `switch <name>`

1. Validate profile exists.
2. Backup current `~/.codex` into timestamped backup folder.
3. Restore selected profile snapshot to `~/.codex`.
4. Update `current_profile`.
5. Print success + backup location.

### `current`

1. Print `current_profile` if present and valid.
2. Else print `none` with guidance.

## 9. Implementation Plan

### Phase 1: Core scaffolding

- Add strict shell settings: `set -euo pipefail`.
- Implement common helpers:
  - `err()`, `info()`, `usage()`
  - `require_dir()`, `validate_profile_name()`
  - `copy_codex_dir()`, `backup_current_codex()`

### Phase 2: Core commands

- Implement `add`, `save`, `list`, `switch`, `current`, `help`.
- Wire a `case "$1" in ... esac` command dispatcher.

### Phase 3: Safety and polish

- Add overwrite prompts + `--force` handling.
- Improve error messaging and exit codes.
- Add shellcheck fixes and portability checks.

### Phase 4: Verification

- Manual test matrix (see section 10).
- Validate profile switches preserve expected Codex state.

## 10. Acceptance Criteria

- User can create two profiles (`work`, `personal`) from different `~/.codex` states.
- `list` shows both profiles and marks active one.
- `switch work` and `switch personal` are reversible with no data loss.
- A backup directory is created on each switch.
- Invalid profile names are rejected with actionable errors.
- Script returns non-zero exit code for all failure cases.

## 11. Test Plan (Manual)

- `add work` on first run creates profile and exits `0`.
- Re-running `add work` fails without `--force`.
- `add personal` after `add work` updates `current`/`list` to `personal` immediately.
- `save work` updates snapshot after changing local `~/.codex`.
- `switch work` restores expected files and writes backup.
- `list` output remains stable and sorted.
- `current` reflects latest successful switch.
- Simulate missing `~/.codex` and verify safe failure/guidance.

## 12. Risks and Mitigations

- Risk: accidental overwrite of active state.
  - Mitigation: mandatory backup + guarded overwrite path.
- Risk: interrupted copy leaves corrupted state.
  - Mitigation: staged copy then atomic move.
- Risk: path/whitespace bugs in shell.
  - Mitigation: quote all expansions; run shellcheck.

## 13. Future Enhancements

- `remove <name>` command with safeguards.
- `rename <old> <new>` command.
- Optional profile metadata (`last_used`, notes).
- Optional `export`/`import` profile archives.

## 14. Alternatives Considered (Rejected for v1)

### A) Compressed profile snapshots (`.zip`)

Considered approach:

- Save each profile as a zip archive and extract during `switch`.

Why rejected for v1:

- Adds compression/decompression overhead to common flows.
- Increases script complexity and failure surface area.
- Makes local inspection/debugging harder than directory snapshots.

Decision:

- Keep `save`/`switch` directory-based for reliability and speed.
- Revisit compression for explicit `export`/`import` workflows.

### B) Symlink-based switching (`~/.codex` -> profile dir)

Considered approach:

- Switch profiles by repointing a symlink instead of copying/restoring files.

Why rejected for v1:

- More fragile if Codex or tooling expects a real directory.
- Higher risk of broken targets and confusing failure modes.
- Harder operational debugging and support burden.

Decision:

- Use copy/restore semantics as the default and only v1 behavior.
- Revisit as an optional advanced mode after core flow is proven stable.
