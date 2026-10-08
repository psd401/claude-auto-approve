---
type: Data Artifact
title: Auto-Approval Audit Log (permissions.log)
description: Format, write semantics, truncation, and retention of the JSONL permissions.log that records every auto-approval made by the PermissionRequest hook.
tags: [audit-log, jsonl, logging, permissions]
timestamp: 2026-10-08T22:53:10Z
openwiki:
  roles: [domain, operations]
  change_kinds: [log-format, persistence]
  source_paths: [auto-approve-safe.sh]
  symbols: [LOG_FILE, TRUNCATED_INPUT, TS]
  test_paths: [test-auto-approve.sh]
  invariants:
    - Only approvals are logged; prompted requests produce no log line.
    - Each log line is one JSON object with keys ts, tool, input, reason, decision.
    - Logging failures never change the approval decision.
    - The input field is truncated to 500 characters.
  validation_commands: ["./test-auto-approve.sh"]
---

# Auto-Approval Audit Log

Every time the hook approves a request, it appends one JSON object to a JSONL file. This is the only record of what was auto-approved, and the README recommends reviewing it periodically to tune allow and deny rules. The writer lives at the end of [Hook decision flow](../architecture/hook-decision-flow.md).

## When to consult this page

Consult this page when changing the log schema, when debugging why a command was approved, or when writing retention tooling. The retention recipe itself is in [Installation and configuration](../operations/installation-and-configuration.md).

## Location

- Default: `$HOME/.claude/permissions.log`.
- Override: `CLAUDE_PERMISSIONS_LOG`, used by the test suite to write into a temp file.

## Entry schema

```json
{"ts":"2026-03-20T17:23:25","tool":"Bash","input":"echo \"test\" && git status","reason":"compound command","decision":"allow"}
```

| Key | Source |
|---|---|
| `ts` | `date -u +%Y-%m-%dT%H:%M:%S`, UTC without a zone suffix |
| `tool` | `tool_name` from the hook input |
| `input` | The Bash command after whitespace trimming, or the `file_path` for Read/Write/Edit; empty for other tools |
| `reason` | `reason` from the hook input, or empty |
| `decision` | Always `"allow"`; no other decision value is ever written |

The object is produced with `jq -n -c` and `--arg`, so quoting in commands and paths is escaped correctly.

## Write semantics

- The entry is written after the allow JSON is printed, so stdout is never delayed by logging.
- The append is `>> "$LOG_FILE" 2>/dev/null || true`. A missing directory or a permissions problem cannot change the decision. Note that a missing `jq` stops the hook before the log step, so it is a dependency failure, not a logging failure.
- Input is truncated with `${TOOL_INPUT:0:500}` before encoding.
- Denied and prompted requests are not logged. The log therefore shows only auto-approvals; it cannot show what the user was asked about.

## Retention

The file is never rotated by the hook. The README's optional `SessionStart` snippet prunes lines older than seven days by filtering on the `ts` string. Because `ts` is a lexicographically sortable ISO-like string, the `>=` comparison in that snippet works, and changing the timestamp format would break it.

## Invariants for future changes

- Keep one JSON object per line; the test "log file created with valid JSON and correct fields" parses the file with `jq`.
- Keep the key names stable. The retention snippet depends on `ts`, and the README's log example documents the rest.
- Keep the `ts` format sortable, or update the README retention snippet in the same change.

## Focused tests

- The "Log file verification (TEST-008)" section of `test-auto-approve.sh` runs one approval with `CLAUDE_PERMISSIONS_LOG` pointed at a temp file and checks `tool` and `input`.
- It does not check `ts`, `reason`, truncation, or the 500-character limit; add focused checks there if those change.

## Related pages

- [Hook decision flow](../architecture/hook-decision-flow.md) owns the point at which the entry is written.
- [Installation and configuration](../operations/installation-and-configuration.md) covers the environment override and the rotation snippet.
- [Test suite](../testing/test-suite.md) describes the log-verification test.
