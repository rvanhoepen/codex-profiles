# codex-profiles

[![Smoke Tests](https://github.com/rvanhoepen/codex-profiles/actions/workflows/smoke.yml/badge.svg)](https://github.com/rvanhoepen/codex-profiles/actions/workflows/smoke.yml)

Switch between local Codex account states by snapshotting `~/.codex` into named profiles.

## Quick Start

```bash
./codex-profiles.sh add work
./codex-profiles.sh add personal
./codex-profiles.sh list
./codex-profiles.sh switch work
./codex-profiles.sh save work
./codex-profiles.sh current
```

## Command Reference

```bash
./codex-profiles.sh add <name>         # create profile from current ~/.codex
./codex-profiles.sh save [name]        # save current ~/.codex into named/current profile
./codex-profiles.sh list               # list all profiles
./codex-profiles.sh switch <name>      # restore profile into ~/.codex
./codex-profiles.sh current            # print active profile
./codex-profiles.sh help
```

Notes:

- Profile data is stored in `~/.codex-profiles/profiles/<name>/codex`.
- `switch` creates a timestamped backup in `~/.codex-profiles/backups`.
- Use `--force` to skip overwrite confirmations.

## Example Workflow

```bash
# Start in work account state
./codex-profiles.sh add work

# Change Codex account/session in the app, then capture it
./codex-profiles.sh add personal

# Switch any time
./codex-profiles.sh switch work
./codex-profiles.sh switch personal

# Save updates back to active profile
./codex-profiles.sh save
```

## Smoke Tests

Run the local smoke test script:

```bash
./tests/smoke.sh
```

The test uses a temporary `HOME` so it will not touch your real `~/.codex`.
