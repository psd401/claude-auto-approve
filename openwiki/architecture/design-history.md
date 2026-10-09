---
type: Design History
title: Design History and Rationale
description: Why the hook is a deny-gate, and why its current guards exist, traced through the repository's commit history from the initial release to the workflow additions.
tags: [design, history, rationale, security]
timestamp: 2026-10-09T21:46:22Z
openwiki:
  roles: [architecture, repository]
  change_kinds: [design-rationale, regression-history]
  source_paths: [auto-approve-safe.sh, test-auto-approve.sh, README.md, .github/workflows/openwiki-update.yml, .github/workflows/claude-review.yml]
  symbols: [AskUserQuestion guard, jq empty settings validation, TOOL_INPUT whitespace trim]
  test_paths: [test-auto-approve.sh]
  invariants:
    - The hook falls back to prompting whenever it cannot prove a request is safe to approve.
    - Settings parse failures must never empty the rule sets.
  validation_commands: ["./test-auto-approve.sh"]
---

# Design History and Rationale

This page explains why the code looks the way it does. Each guard in [Hook decision flow](hook-decision-flow.md) traces back to a specific finding in the commit history. The subjects below are the durable record of each decision on `main`, in order.

## Why a deny-gate

The README's problem statement is that Claude Code's built-in heuristics produce false positives on compound commands, command substitution, quoted flag names, and cross-directory reads. These block subagents, which cannot be answered by a parent agent, and enterprise policies rule out `dangerouslySkipPermissions`. The chosen design inverts the default: approve everything except what the user's own `deny` and `ask` rules match. That makes `settings.json` the single source of truth, which is why [Rule matching](../domain/rule-matching.md) is the core of the product.

## Timeline of decisions

**Initial release.** The hook, README, and a 37-case harness were introduced together. The deny-gate, the audit log, and the Read/Write/Edit cross-application were all present from the start.

**AskUserQuestion guard.** A later Claude Code update routed `AskUserQuestion` through `PermissionRequest`. The hook had no rule for it and approved it, which swallowed the user's answers. The fix is an unconditional early exit before tool extraction. It is a hard-coded exception rather than a settings rule, so it applies even when the user has no deny entries.

**Malformed-settings and bypass hardening.** A review found several issues, and this release also expanded the harness from 37 to 66 cases:

- The P0 bypass: a malformed `settings.json` made `jq` fail silently, which emptied all deny and ask rules and approved everything. Validation with `jq empty` before rule extraction now prevents this.
- The whitespace bypass: a leading space before `sudo` evaded `sudo *`. Bash commands are now trimmed before matching.
- Tools with a pattern rule but no extractable input are now blocked conservatively instead of being approved.
- Empty Bash commands bail to prompt instead of approving.
- `CLAUDE_SETTINGS` and `CLAUDE_PERMISSIONS_LOG` became overridable so the harness can use temp files. This is why the environment overrides exist; see [Installation and configuration](../operations/installation-and-configuration.md).

**OpenWiki addition.** The repository gained `.github/workflows/openwiki-update.yml`, a thin caller of an organization-wide reusable workflow. It runs on pushes to `main` (excluding `openwiki/**` changes), on a weekly schedule, and on manual dispatch. See [Wiki maintenance](../operations/wiki-maintenance.md).

**Claude review addition.** Commit `1ef84f6` added `.github/workflows/claude-review.yml`, a caller of an organization-wide reusable review workflow. The commit message describes the review as advisory: it posts one comment and never approves or blocks a merge. Dependabot actors are skipped because the caller needs `id-token: write`. See [Claude review workflow](../operations/claude-review-workflow.md).

**Secret scoping.** Both workflow callers originally used `secrets: inherit`, which handed every organization and repository secret to a reusable workflow that needs one or two. Commit `4563a70` narrowed the Claude review caller to `BEDROCK_API_KEY`. Commit `e0ddb17` narrowed the OpenWiki caller to `BEDROCK_API_KEY` and `PSD_AUTOMATION_APP_PRIVATE_KEY`. Both commit messages record the decision as Kris Hagel's, dated 2026-10-09. The rule that follows is that a caller passes only the secrets its reusable workflow reads. See [Wiki maintenance](../operations/wiki-maintenance.md) and [Claude review workflow](../operations/claude-review-workflow.md).

## Patterns to preserve

- Fail closed on the hook's side means fail to prompt. Every fallback path, including the `set -euo pipefail` plus `trap 'exit 0' ERR` combination, exits with no output.
- Guards belong before rule loading when they are unconditional (the AskUserQuestion exit) and after validation when they depend on settings (the `jq empty` check).
- New deny semantics belong in the rule loop with a matching test. Malformed entries are skipped with `continue`, so one bad entry does not disable other rules; the test section for malformed rules pins this.

## Open questions from the code

These are behaviors the history does not settle; they are documented as gaps in [Rule matching](../domain/rule-matching.md#known-gaps-verified-by-probe):

- Compound commands are matched as whole strings, so a deny or ask segment after `&&` is not caught.
- Tool names that contain digits, underscores, or colons cannot be expressed in rules.

## Related pages

- [Architecture overview](overview.md) gives the system-level view.
- [Test suite](../testing/test-suite.md) lists the regression tests that came out of the hardening work.
