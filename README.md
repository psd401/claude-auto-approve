# claude-auto-approve

A `PermissionRequest` hook for [Claude Code](https://code.claude.com) that auto-approves benign permission prompts while respecting your deny/ask rules.

## Problem

Claude Code's hardcoded safety heuristics produce false positives that block subagents and interrupt workflows:
- Compound commands (`git log && echo "---"`)
- Command substitution (`echo $(date)`)
- Quoted characters in flag names
- Cross-directory reads for multi-project setups

Subagents get stuck waiting on these prompts with no way for the parent agent to approve them. Enterprise policies block `dangerouslySkipPermissions`, so there's no simple workaround.

## Solution

A deny-gate approach: auto-approve everything **except** commands matching your `deny` and `ask` rules in `settings.json`. Your existing rules become the single source of truth.

### How it works

1. Hook receives the permission request (tool name + input)
2. Loads `deny` and `ask` patterns from `~/.claude/settings.json`
3. If the request matches any deny/ask pattern → exits silently (normal prompt appears)
4. Otherwise → returns `allow` decision (prompt suppressed)

### Features

- **Bash pattern matching** — native glob matching for shell commands
- **File path globstar** — `**/` patterns converted to regex for Read/Write/Edit tools
- **Deny cross-application** — `Read(.env*)` deny rules also block `Edit` and `Write` on the same paths
- **JSONL audit log** — every auto-approval logged to `~/.claude/permissions.log`
- **Safe fallback** — any error in the hook exits silently, falling back to the normal prompt

## Installation

### 1. Copy the hook script

```bash
cp auto-approve-safe.sh ~/.claude/hooks/auto-approve-safe.sh
chmod +x ~/.claude/hooks/auto-approve-safe.sh
```

### 2. Add the hook to `~/.claude/settings.json`

Add this inside the `"hooks"` object:

```json
"PermissionRequest": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "~/.claude/hooks/auto-approve-safe.sh",
        "timeout": 5
      }
    ]
  }
]
```

### 3. (Optional) Enable cross-directory reads for subagents

Add `additionalDirectories` inside the `"permissions"` object:

```json
"permissions": {
  "allow": [...],
  "deny": [...],
  "additionalDirectories": ["/path/to/your/code"]
}
```

### 4. (Optional) Add log rotation

Add a `SessionStart` hook to prune log entries older than 7 days:

```bash
PERM_LOG="$HOME/.claude/permissions.log"
if [[ -f "$PERM_LOG" ]]; then
    CUTOFF=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d 2>/dev/null || echo "")
    if [[ -n "$CUTOFF" ]]; then
        TMP_LOG=$(mktemp)
        jq -c "select(.ts >= \"$CUTOFF\")" "$PERM_LOG" > "$TMP_LOG" 2>/dev/null || true
        mv "$TMP_LOG" "$PERM_LOG" 2>/dev/null || rm -f "$TMP_LOG"
    fi
fi
```

## Testing

Run the test suite:

```bash
./test-auto-approve.sh
```

37 tests covering:
- Bash approve (compound commands, substitution)
- Bash deny (sudo, rm -rf, git reset --hard, etc.)
- Bash ask (git push, rm)
- Read/Edit/Write deny cross-application (secrets, keys, credentials)
- Safe file approvals
- Other tool approvals (Glob, Grep, WebSearch)

## How deny rules work

The hook reads patterns from your existing `settings.json`:

```json
"deny": [
  "Read(.env*)",
  "Read(**/.env*)",
  "Read(**/*.pem)",
  "Bash(rm -rf *)",
  "Bash(sudo *)"
],
"ask": [
  "Bash(git push*)",
  "Bash(rm *)"
]
```

Both `deny` and `ask` rules prevent auto-approval. The hook never overrides these — if a command matches, you'll see the normal permission prompt.

Read deny rules are cross-applied to Edit and Write tools automatically.

## Log format

Auto-approvals are logged as JSONL to `~/.claude/permissions.log`:

```json
{"ts":"2026-03-20T17:23:25","tool":"Bash","input":"echo \"test\" && git status","reason":"compound command","decision":"allow"}
```

Review the log periodically to tune your allow/deny rules.

## Requirements

- Claude Code
- `jq` (for JSON parsing)
- `bash` 4+ (for `[[ =~ ]]` regex matching)

## License

MIT
