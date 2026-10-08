---
type: Test Suite
title: Test Suite (test-auto-approve.sh)
description: Structure of the bash test harness for the auto-approve hook, its assertion helpers, section-by-section behavior matrix, environment dependencies on HOME and the default settings file, and narrow commands for running it quietly.
tags: [testing, harness, bash, regression, validation]
timestamp: 2026-10-08T22:53:10Z
openwiki:
  roles: [testing]
  change_kinds: [test-coverage, validation]
  source_paths: [test-auto-approve.sh, auto-approve-safe.sh]
  symbols: [assert_approve, assert_prompt, assert_approve_with_settings, assert_prompt_with_settings, PASS, FAIL]
  test_paths: [test-auto-approve.sh]
  invariants:
    - Each case feeds one JSON object to the hook and asserts on stdout only; empty stdout counts as prompt.
    - Settings-dependent cases use CLAUDE_SETTINGS pointing at a temp file created under TMPDIR_TEST.
    - The suite exits 1 when any assertion fails and 0 otherwise.
  validation_commands: ["./test-auto-approve.sh", "./test-auto-approve.sh | grep -E 'FAIL|Results'"]
---

# Test Suite

`test-auto-approve.sh` is a single bash harness with 66 cases. It runs `auto-approve-safe.sh` as a subprocess for each case and checks stdout. It has no unit-level access to the hook's functions, so every assertion is end to end through the JSON contract described in [Hook decision flow](../architecture/hook-decision-flow.md).

## When to consult this page

Consult this page to find the existing test for a behavior before adding one, to choose a narrow validation command, or to understand why a run fails on a machine without a Claude Code settings file.

## Harness mechanics

- `HOOK` resolves to `auto-approve-safe.sh` next to the test script.
- `TMPDIR_TEST` is created with `mktemp -d` and removed by an `EXIT` trap. All temp settings and log files live there.
- `assert_approve` and `assert_prompt` run the hook with the default settings path. `assert_approve_with_settings` and `assert_prompt_with_settings` add `CLAUDE_SETTINGS=<file>`.
- "Approve" means stdout contains `"allow"`. "Prompt" means stdout is empty or lacks `"allow"`.
- Results accumulate in `PASS` and `FAIL`; each failure prints the actual output.

## Behavior matrix

The section headers are stable, searchable strings. Search `test-auto-approve.sh` for the header text to jump to a case.

| Behavior under test | Section header (search key) | Expected |
|---|---|---|
| Bash false positives (compound `&&`, command substitution) | "Bash: should approve (heuristic false positives)" | allow |
| Bash deny rules (sudo, rm -rf, git reset --hard, force push, dd, chmod, nc) | "Bash: should prompt (deny rules)" | prompt |
| Bash ask rules (git push, rm) | "Bash: should prompt (ask rules)" | prompt |
| Read secrets under deny rules | "Read: should prompt (deny rules for secrets)" | prompt |
| Edit and Write cross-application | "Edit: should prompt (deny rules cross-apply to Write/Edit)", "Write: should prompt (deny rules cross-apply to Write/Edit)" | prompt |
| Safe Edit, Write, Read files | "Edit/Write: should approve (safe files)", "Read: should approve (safe files)" | allow |
| Other tools (Glob, Grep, WebSearch) | "Other tools: should approve" | allow |
| Whitespace bypass | "Bash: should prompt (whitespace bypass prevention, SEC-001)" | prompt |
| Malformed or empty input | "Malformed input: should prompt (TEST-001)" | prompt |
| Missing settings file | "Missing settings.json: should prompt (TEST-002)" | prompt |
| Malformed settings file | "Malformed settings.json: should prompt (COR-001)" | prompt |
| Settings with no deny or ask keys | "Valid settings with no deny/ask keys: should approve (TEST-002 edge)" | allow |
| Malformed rules skipped, valid rules still apply | "Malformed rules in settings: should still process valid rules (TEST-004)" | mixed |
| Globstar and trailing-glob file paths | "glob_to_regex edge cases via file paths (TEST-003)" | prompt or allow |
| Cross-tool isolation | "Cross-tool isolation (TEST-006)" | mixed |
| Empty Bash command, empty or missing file_path | "Empty command/file_path (TEST-009, TEST-010)" | prompt |
| Bash glob edge cases | "Bash glob edge cases (TEST-005)" | mixed |
| Audit log content | "Log file verification (TEST-008)" | file created with tool `Bash` and input `echo hello` |

Stateful lifecycle matrix (initial state, transitions, reset, reuse): not applicable. The hook is stateless between invocations. Isolation between cases comes from separate settings files and log files per assertion.

## Known coverage gaps

The following verified behaviors have no assertion, so a regression cannot be detected by this suite:

- Compound-command bypass of prefix rules (for example `git status && sudo ls` is approved). See [Rule matching](../domain/rule-matching.md#known-gaps-verified-by-probe).
- Non-letter tool names in rules are silently ignored.
- Bare `sudo` is approved under `Bash(sudo *)`.
- The audit log's `ts`, `reason`, and 500-character truncation are not asserted.
- The `AskUserQuestion` early exit has no assertion in this suite. Add one next to the "Other tools" section if that guard changes.

## Environment dependencies

These are real constraints you will hit when running the suite:

- `HOME` must be set. The script uses `set -u`. With `HOME` unset, the hook aborts and prints nothing, so every approve case fails. The run in this environment reported 16 failures that way.
- Ten approve cases use the default settings path and do not set `CLAUDE_SETTINGS`. They are: "compound && with echo", "simple allowed command", "command substitution", "Edit normal source file", "Write normal source file", "Read normal source file", "Read package.json", "Glob", "Grep", and "WebSearch". These pass only when `$HOME/.claude/settings.json` exists. They are the cases that fail when `HOME` is set but has no settings file.
- Prompt-expecting cases pass with or without settings, so a failure list containing only approve cases usually indicates an environment problem, not a rule regression.

## Commands

- Full run: `./test-auto-approve.sh`. Exits 1 on any failure.
- Quiet run that keeps failure details: `set -o pipefail; ./test-auto-approve.sh | grep -E 'FAIL|Results'`.
- Syntax-only check before running: `bash -n auto-approve-safe.sh`.

The suite has no external services and no build step, so it is the appropriate narrow check for any change to the hook or the harness. No broader validation is defined in this repository.

## Adding a test

1. Find the section that matches the behavior in the matrix above, or add a new section with a header in the same style.
2. Use `assert_approve` or `assert_prompt` for default settings, or the `_with_settings` variants with a file under `TMPDIR_TEST`.
3. Keep JSON in single quotes and escape inner quotes, as the existing cases do.
4. If the total changes, update the "66 tests" count in the README's Testing section. [Quickstart](../quickstart.md) does not state a count.

## Related pages

- [Hook decision flow](../architecture/hook-decision-flow.md) defines the outcomes the tests assert.
- [Installation and configuration](../operations/installation-and-configuration.md) covers the environment overrides the tests use.
- [Audit log](../domain/audit-log.md) describes the log fields that the log test checks only partially.
hecks only partially.
