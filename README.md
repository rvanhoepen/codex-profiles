# codex-profiles

[![Smoke Tests](https://github.com/rvanhoepen/codex-profiles/actions/workflows/smoke.yml/badge.svg)](https://github.com/rvanhoepen/codex-profiles/actions/workflows/smoke.yml)

Switch between local Codex account states by snapshotting `~/.codex` into named profiles.

## Installation

```bash
./install.sh
```

By default this installs to `~/.local/bin/codex-profiles`.

If `~/.local/bin` is not on your `PATH`, add this to your shell profile (for example `~/.zshrc`):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Uninstall:

```bash
./uninstall.sh
```

## Quick Start

```bash
codex-profiles add work
codex-profiles add personal
codex-profiles list
codex-profiles switch work
codex-profiles save work
codex-profiles current
```

## Command Reference

```bash
codex-profiles add <name>         # create profile from current ~/.codex
codex-profiles save [name]        # save current ~/.codex into named/current profile
codex-profiles list               # list all profiles
codex-profiles switch <name>      # restore profile into ~/.codex
codex-profiles current            # print active profile
codex-profiles help
```

For local development without installing, replace `codex-profiles` with `./codex-profiles.sh`.

Notes:

- Profile data is stored in `~/.codex-profiles/profiles/<name>/codex`.
- `switch` creates a timestamped backup in `~/.codex-profiles/backups`.
- Use `--force` to skip overwrite confirmations.

## Example Workflow

```bash
# Start in work account state
codex-profiles add work

# Change Codex account/session in the app, then capture it
codex-profiles add personal

# Switch any time
codex-profiles switch work
codex-profiles switch personal

# Save updates back to active profile
codex-profiles save
```

## Smoke Tests

Run the local smoke test script:

```bash
./tests/smoke.sh
```

The test uses a temporary `HOME` so it will not touch your real `~/.codex`.
