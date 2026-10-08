---
type: Operations Guide
title: Installation and Configuration
description: How to install the PermissionRequest hook into Claude Code, register it in settings.json, enable cross-directory reads, configure optional log retention, and which environment variables and requirements the hook depends on.
tags: [installation, configuration, settings, claude-code, environment]
timestamp: 2026-10-08T22:53:10Z
openwiki:
  roles: [operations, delivery]
  change_kinds: [configuration, installation]
  source_paths: [auto-approve-safe.sh, README.md]
  symbols: [SETTINGS, LOG_FILE]
  test_paths: [test-auto-approve.sh]
  invariants:
    - The hook is registered only through the PermissionRequest hook array in ~/.claude/settings.json.
    - CLAUDE_SETTINGS and CLAUDE_PERMISSIONS_LOG override the default settings and log paths.
    - jq and bash 4+ are required at runtime.
  validation_commands: ["bash -n auto-approve-safe.sh", "./test-auto-approve.sh"]
---

# Installation and Configuration

This repository ships a single hook script and no package manager artifacts. Installing means copying the script into `~/.claude/hooks/`, registering it as a `PermissionRequest` command hook, and writing deny and ask rules into `settings.json`. The rules themselves are documented in [Deny and ask rule matching](../domain/rule-matching.md).

## When to consult this page

Use this page when a user cannot get auto-approval working, when changing the README installation steps, or when a change adds a new environment variable or requirement. Check that the hook is installed before debugging its logic.

## Setup steps

1. Copy `auto-approve-safe.sh` to `~/.claude/hooks/auto-approve-safe.sh` and make it executable.
2. Add a `PermissionRequest` entry under the `hooks` object in `~/.claude/settings.json`, pointing its `command` at the script with `timeout` 5. The README shows the exact JSON.
3. Optional: add `additionalDirectories` under `permissions` so subagents can read other project directories. This is a Claude Code setting, not something the hook reads.
4. Optional: add a `SessionStart` hook that prunes the audit log (see below).
5. Put deny and ask entries under `permissions` in the same `settings.json`. The hook reads them at every invocation, so edits take effect without reinstalling.

## Runtime environment

| Setting | Default | Purpose |
|---|---|---|
| `CLAUDE_SETTINGS` | `$HOME/.claude/settings.json` | Settings file to read deny and ask rules from |
| `CLAUDE_PERMISSIONS_LOG` | `$HOME/.claude/permissions.log` | Audit log destination (see [Audit log](../domain/audit-log.md)) |

Requirements, as stated in the README and enforced by the script:

- Claude Code with the `PermissionRequest` hook event.
- `jq` on `PATH`. Missing `jq` makes parsing fail, which falls back to the prompt.
- `bash` 4 or newer. The script uses `[[ =~ ]]` and substring expansion. Its shebang is `#!/usr/bin/env bash`.
- `HOME` must be set. The script runs under `set -u`, so an unset `HOME` makes it abort and prompt.

## Log retention recipe

The README's optional `SessionStart` snippet keeps only lines whose `ts` is on or after a cutoff seven days back. It tries BSD `date -v-7d` and GNU `date -d '7 days ago'`, and writes the filtered file through `mktemp`. The snippet depends on the timestamp format in [Audit log](../domain/audit-log.md); if that format changes, update the snippet in the same change.

## Behavior when misconfigured

- Missing settings file: every request prompts.
- Malformed JSON in settings: every request prompts. The hook does not approve everything in this case.
- Unknown or malformed rule entries: skipped; valid entries still apply.

These fallbacks are described in [Hook decision flow](../architecture/hook-decision-flow.md).

## Change guidance

- The README is the user-facing source for these steps. If a change alters the hook JSON shape, the timeout, the install path, or an environment variable, update the README and this page together.
- The `hooks` snippet uses `PermissionRequest` with `"type": "command"`. Changing the event name breaks registration silently, because the hook would never be invoked.
- Do not document or suggest storing secrets in these files. The hook only reads deny and ask rule strings.

## Focused validation

- `bash -n auto-approve-safe.sh` checks syntax with no output on success.
- `./test-auto-approve.sh` exercises the environment overrides: missing and malformed settings use `CLAUDE_SETTINGS`, and the log test uses `CLAUDE_PERMISSIONS_LOG`.
- Installation itself (copying into `~/.claude/hooks/` and editing the real `settings.json`) is a user-machine step and has no automated check in this repository.

## Related pages

- [Architecture overview](../architecture/overview.md) places the installed hook in the Claude Code flow.
- [Test suite](../testing/test-suite.md) explains how the test harness sets the environment overrides.
