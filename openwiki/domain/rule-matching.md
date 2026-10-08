---
type: Domain Rule
title: Deny and Ask Rule Matching
description: Semantics of deny and ask rules read from Claude Code settings.json, including Bash glob matching, file-path globstar regexes, Read/Write/Edit cross-application, bare-tool rules, and verified gaps such as compound commands and non-letter tool names.
tags: [rules, deny, ask, glob, matching, settings]
timestamp: 2026-10-08T22:53:10Z
openwiki:
  roles: [domain, architecture]
  change_kinds: [rule-matching, glob, cross-tool]
  source_paths: [auto-approve-safe.sh]
  symbols: [glob_to_regex, FILE_PATH_TOOLS, ALL_BLOCK_RULES, BLOCKED]
  test_paths: [test-auto-approve.sh]
  invariants:
    - Rules are read only from permissions.deny and permissions.ask; permissions.allow is never consulted.
    - Bash rule patterns are matched as whole-string bash globs against the trimmed command.
    - Read, Write, and Edit share rules in both directions; no other tool pairs share rules.
    - A bare tool-name rule blocks every call of that tool.
    - A pattern rule for a tool with no extractable input blocks conservatively.
  validation_commands: ["./test-auto-approve.sh"]
---

# Deny and Ask Rule Matching

The hook has no rules of its own. It treats the user's `permissions.deny` and `permissions.ask` entries in `settings.json` as the single source of truth and withholds auto-approval when any entry matches. This page explains how entries are parsed and matched. The control flow that calls this logic is in [Hook decision flow](../architecture/hook-decision-flow.md).

## When to consult this page

Consult this page when a command or path is unexpectedly approved or unexpectedly prompted, when adding support for new rule syntax, or when changing glob semantics. Check the [known gaps](#known-gaps-verified-by-probe) before assuming the matcher is complete.

## Rule grammar

Each entry is parsed with two regexes in order:

- `ToolName(pattern)` where the tool name is letters only (`^([A-Za-z]+)\((.+)\)$`).
- A bare `ToolName` (letters only), which matches every call to that tool.

Any other entry is skipped silently. This includes names with digits, underscores, or colons, so MCP-style names such as `mcp__srv__danger` never match even when listed under `deny`.

## Tool pairing

The matcher skips a rule unless it names the same tool as the request, or both are in the file-path group `Read Write Edit`:

- Same tool: always compared.
- `Read`, `Write`, `Edit` rules apply to each other, so `Read(**/.env*)` also blocks `Edit` and `Write` on the same paths. The test section "Cross-tool isolation" covers this.
- Other tools are isolated; a `Bash(...)` rule never blocks `Read`, and a `Read(...)` rule never blocks `Bash`.

## Matching engines

Bash and file-path tools use different engines:

- Bash: `[[ "$TOOL_INPUT" == $RULE_PATTERN ]]` with an unquoted right-hand side, so the pattern is a bash glob matched against the whole trimmed command. `*` matches any characters including `/` and spaces.
- File-path tools (Read, Write, Edit): `glob_to_regex` converts the pattern to an ERE and matches with `=~`. The conversion uses placeholders so sed passes do not interfere:
  - trailing `**` becomes `.*`,
  - `**/` becomes `(^|.*/)`, which matches any directory prefix including none,
  - remaining `**` becomes `.*`,
  - `*` becomes `[^/]*`,
  - dots are escaped, and the regex is end-anchored with `$`.
  The regex is not start-anchored unless the pattern begins with `**/`, so `Read(.env*)` also matches a path whose final segment merely ends in `.env`.

A file-path rule whose input is empty blocks conservatively. This is the `elif [[ -z "$TOOL_INPUT" ]]` branch, which also applies to tools such as `Glob` or `WebSearch` when they have a pattern rule.

## Bare-tool rules

A bare entry like `"Bash"` or `"Read"` sets `BLOCKED` for every call of that tool, regardless of input. Within the Read/Write/Edit group this also covers the cross-matched tools.

## Known gaps (verified by probe)

These behaviors were reproduced against the current script. None is covered by `test-auto-approve.sh`, and the README describes the deny gate as authoritative, so treat them as product risks:

- **Compound commands bypass prefix rules.** A Bash rule matches the whole command string from the start. `git status && git push origin main` is auto-approved despite `Bash(git push*)` in `ask`, and `git status && sudo ls` is auto-approved despite `Bash(sudo *)` in `deny`. A prefix pattern blocks only when the whole command begins with it, so a denied segment that is not first goes undetected.
- **Non-letter tool names are ignored.** A deny entry for `mcp__srv__danger` never matches, so calls to that tool are auto-approved.
- **Bare `sudo` is not covered by `Bash(sudo *)`.** The glob requires a following space, so `sudo` alone is approved.
- **Suffix matches are broad but not unbounded.** `Read(.env*)` blocks `/home/u/foo.env` and `/home/u/project/.env.local`, which is intended for secrets, but it can also block unrelated files whose final segment ends in `.env`.

When fixing a gap, change matching only inside the rule loop and add a focused case to the test section named in [Test suite](../testing/test-suite.md). Keep the current matcher for file paths unless the whole regex builder is being reworked, since `glob_to_regex` has its own edge-case section.

## Invariants

- The loop breaks on the first match, so rule order does not change the decision; every rule outcome is "blocked or not".
- Whitespace trimming happens before Bash matching, so leading or trailing spaces, or tabs, cannot evade a rule (test section "whitespace bypass prevention").
- A non-matching request is approved only after every rule is evaluated and none matched.

## Focused tests

| Behavior | Test section header in `test-auto-approve.sh` |
|---|---|
| Bash deny and ask patterns | "Bash: should prompt (deny rules)", "Bash: should prompt (ask rules)" |
| Bash glob edge cases | "Bash glob edge cases (TEST-005)" |
| Read/Write/Edit cross-application | "Edit: should prompt (deny rules cross-apply to Write/Edit)", "Cross-tool isolation (TEST-006)" |
| glob_to_regex nested paths and trailing globstar | "glob_to_regex edge cases via file paths (TEST-003)" |
| Malformed rules skipped | "Malformed rules in settings: should still process valid rules (TEST-004)" |

Run `./test-auto-approve.sh` to execute these; see [Test suite](../testing/test-suite.md) for how to scope output.

## Related pages

- [Hook decision flow](../architecture/hook-decision-flow.md) calls this matching loop and owns the surrounding fallbacks.
- [Installation and configuration](../operations/installation-and-configuration.md) describes where `settings.json` comes from and how users write these rules.
- [Design history](../architecture/design-history.md) explains the whitespace and cross-tool decisions.
