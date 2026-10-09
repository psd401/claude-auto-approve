# Files

- [Design History and Rationale](design-history.md) - Why the hook is a deny-gate, and why its current guards exist, traced through the repository's commit history from the initial release to the workflow additions.
- [PermissionRequest Hook Decision Flow](hook-decision-flow.md) - How auto-approve-safe.sh turns a Claude Code PermissionRequest into an allow decision or a silent fallback to the normal prompt, including every early exit and fail-safe path.
- [claude-auto-approve Architecture Overview](overview.md) - System-level view of the claude-auto-approve PermissionRequest hook for Claude Code, its components (hook script, settings.json rules, audit log, test harness, OpenWiki, security scan, and Claude review workflows), their relationships, and the repository layout.
