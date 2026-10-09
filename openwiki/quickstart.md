---
type: Quickstart
title: claude-auto-approve Wiki Quickstart
description: Entry point for the claude-auto-approve knowledge base; a Claude Code PermissionRequest bash hook that auto-approves prompts unless user deny or ask rules match, with task routing to source files, symbols, tests, and validation commands.
tags: [quickstart, overview, routing, claude-code, permission-hook]
timestamp: 2026-10-08T22:53:10Z
openwiki:
  roles: [repository, architecture]
  change_kinds: [navigation]
  source_paths: [auto-approve-safe.sh, test-auto-approve.sh, README.md, .github/workflows/security-scan.yml]
  symbols: [auto-approve-safe.sh, test-auto-approve.sh]
  test_paths: [test-auto-approve.sh]
  invariants:
    - The hook prints an allow decision or nothing; it never prints a deny.
  validation_commands: ["./test-auto-approve.sh"]
---

# claude-auto-approve Wiki Quickstart

`claude-auto-approve` is a [Claude Code](https://code.claude.com) `PermissionRequest` hook written in bash. Claude Code runs it whenever a tool asks for permission. It prints an allow decision, which suppresses the prompt, unless the request matches a `deny` or `ask` entry in the user's `~/.claude/settings.json`. In that case it prints nothing and the normal prompt appears. Every approval is appended to a JSONL audit log. The point of the design is to unblock subagents, which cannot be answered by a parent agent, without using `dangerouslySkipPermissions`.

The repository is intentionally small: one runtime script (`auto-approve-safe.sh`), one test harness (`test-auto-approve.sh`), a README, the MIT license, and a workflow that refreshes this wiki.

## How this wiki is organized

- **Architecture**: [Overview](architecture/overview.md) for the component map and runtime sequence; [Hook decision flow](architecture/hook-decision-flow.md) for the decision pipeline, fail-safe paths, and output contract; [Design history](architecture/design-history.md) for why each guard exists.
- **Domain**: [Deny and ask rule matching](domain/rule-matching.md) for Bash globs, file-path regexes, cross-tool rules, and verified gaps; [Audit log](domain/audit-log.md) for the `permissions.log` schema and write semantics.
- **Operations**: [Installation and configuration](operations/installation-and-configuration.md) for setup, environment overrides, and log retention; [Wiki maintenance](operations/wiki-maintenance.md) for the OpenWiki refresh workflow.
- **Testing**: [Test suite](testing/test-suite.md) for the harness, behavior matrix, environment dependencies, and quiet commands.

## Task routing

Use this table to go from an intent to the first file, symbol, and test. Start with the page, then open the listed source.

| Change area or intent | Wiki page | Entry points | Important symbols | Focused tests (section headers) | Minimal validation |
|---|---|---|---|---|---|
| Decision flow, early exits, allow output, fallbacks | [Hook decision flow](architecture/hook-decision-flow.md) | `auto-approve-safe.sh` | `TOOL_NAME`, `BLOCKED`, `trap 'exit 0' ERR` | "Malformed input", "Missing settings.json", "Malformed settings.json" | `./test-auto-approve.sh` |
| Bash deny or ask matching | [Rule matching](domain/rule-matching.md) | `auto-approve-safe.sh` rule loop | `ALL_BLOCK_RULES`, `RULE_PATTERN`, `[[ "$TOOL_INPUT" == $RULE_PATTERN ]]` | "Bash: should prompt (deny rules)", "Bash: should prompt (ask rules)", "Bash glob edge cases (TEST-005)" | `./test-auto-approve.sh` |
| File-path globstar and Read/Write/Edit cross-application | [Rule matching](domain/rule-matching.md) | `auto-approve-safe.sh` | `glob_to_regex`, `FILE_PATH_TOOLS` | "glob_to_regex edge cases via file paths (TEST-003)", "Cross-tool isolation (TEST-006)" | `./test-auto-approve.sh` |
| Support input extraction for a new tool | [Hook decision flow](architecture/hook-decision-flow.md) | `TOOL_NAME` if-chain in `auto-approve-safe.sh` | `TOOL_INPUT` | "Other tools: should approve", "Empty command/file_path (TEST-009, TEST-010)" | `./test-auto-approve.sh` |
| Whitespace or bypass hardening for Bash | [Rule matching](domain/rule-matching.md) | `sed` trim in `auto-approve-safe.sh` | `TOOL_INPUT` | "Bash: should prompt (whitespace bypass prevention, SEC-001)" | `./test-auto-approve.sh` |
| Audit log schema, truncation, or retention | [Audit log](domain/audit-log.md) | log block at end of `auto-approve-safe.sh` | `LOG_FILE`, `TRUNCATED_INPUT`, `TS` | "Log file verification (TEST-008)" | `./test-auto-approve.sh` |
| Install steps, settings wiring, env overrides | [Installation and configuration](operations/installation-and-configuration.md) | `README.md`, `auto-approve-safe.sh` | `SETTINGS`, `CLAUDE_SETTINGS`, `CLAUDE_PERMISSIONS_LOG` | "Valid settings with no deny/ask keys" | `bash -n auto-approve-safe.sh` |
| Test harness helpers or adding cases | [Test suite](testing/test-suite.md) | `test-auto-approve.sh` | `assert_approve`, `assert_prompt`, `assert_*_with_settings` | the matching section header | `./test-auto-approve.sh` |
| Why a guard exists or prior regression | [Design history](architecture/design-history.md) | commits: AskUserQuestion fix, malformed-settings hardening | `AskUserQuestion` exit, `jq empty` | "Malformed settings.json: should prompt (COR-001)" (no test covers the `AskUserQuestion` exit) | `./test-auto-approve.sh` |
| OpenWiki refresh or workflow triggers | [Wiki maintenance](operations/wiki-maintenance.md) | `.github/workflows/openwiki-update.yml` | `paths-ignore`, concurrency `openwiki` | none (no tests for workflow) | YAML review; manual `workflow_dispatch` on the host platform |
| Security scan triggers, permissions, or `@main` pin | [Security scan workflow](operations/security-scan-workflow.md) | `.github/workflows/security-scan.yml` | `permissions: contents: read`, `uses: ...reusable-security-scan.yml@main` | none (no tests for workflow) | YAML review; manual `workflow_dispatch` on the host platform |
| Claude review triggers, Dependabot guard, or `id-token` permission | [Claude review workflow](operations/claude-review-workflow.md) | `.github/workflows/claude-review.yml` | `on.pull_request.types`, `if: github.actor != 'dependabot[bot]'`, `permissions: id-token: write` | none (no tests for workflow) | YAML review; open or reopen a non-Dependabot pull request and check the Actions run (no `workflow_dispatch`) |

### Validation

- Default check for any hook or harness change: `./test-auto-approve.sh`. It has no external dependencies and exits 1 when any case fails.
- Quieter variant that keeps failure details: `set -o pipefail; ./test-auto-approve.sh | grep -E 'FAIL|Results'`.
- Syntax-only check: `bash -n auto-approve-safe.sh`.
- Before trusting an approve-case failure, confirm `HOME` is set and `$HOME/.claude/settings.json` exists. Several approve cases depend on it; see [Test suite](testing/test-suite.md#environment-dependencies).

There is no build, package, or release step in this repository, so no broader validation is defined.

## Things to know before changing code

- The hook must print nothing for every non-approval path. Empty output is the prompt fallback that the tests assert.
- The hook never reads `allow` rules and never emits `deny`.
- Compound commands are matched as one string, so a deny or ask rule does not cover segments after `&&`. This is a verified gap; see [Rule matching](domain/rule-matching.md#known-gaps-verified-by-probe).
- Generated files live under `openwiki/`. Do not hand-edit them as a routine fix; see [Wiki maintenance](operations/wiki-maintenance.md).

## Backlog

- Reusable OpenWiki workflow internals (`PSD401/.github/.github/workflows/reusable-openwiki.yml@main`) are evidence-blocked: the file is not in this repository, so the wiki describes only the caller in `.github/workflows/openwiki-update.yml`.
ether the review is a required check) are evidence-blocked: the file is not in this repository, so the wiki describes only the caller in `.github/workflows/claude-review.yml` and the intent recorded in commit `1ef84f6`.
