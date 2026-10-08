# Files

- [Auto-Approval Audit Log (permissions.log)](audit-log.md) - Format, write semantics, truncation, and retention of the JSONL permissions.log that records every auto-approval made by the PermissionRequest hook.
- [Deny and Ask Rule Matching](rule-matching.md) - Semantics of deny and ask rules read from Claude Code settings.json, including Bash glob matching, file-path globstar regexes, Read/Write/Edit cross-application, bare-tool rules, and verified gaps such as compound commands and non-letter tool names.
