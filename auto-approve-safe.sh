#!/usr/bin/env bash
# ABOUTME: PermissionRequest hook that auto-approves benign prompts while respecting deny/ask rules.
# ABOUTME: Reads deny/ask patterns from ~/.claude/settings.json at runtime. Logs approvals to ~/.claude/permissions.log.

set -euo pipefail
trap 'exit 0' ERR

SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
LOG_FILE="${CLAUDE_PERMISSIONS_LOG:-$HOME/.claude/permissions.log}"

# Read hook JSON from stdin
INPUT=$(cat)

# Parse tool info — silent failure returns empty (hook exits with no output = prompt)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null) || true
REASON=$(echo "$INPUT" | jq -r '.reason // ""' 2>/dev/null) || true

# Bail if we can't parse input — fall back to prompting
[[ -z "$TOOL_NAME" ]] && exit 0

# Never auto-approve tools that require user interaction
[[ "$TOOL_NAME" == "AskUserQuestion" ]] && exit 0

# Extract the relevant input value depending on tool type
if [[ "$TOOL_NAME" == "Bash" ]]; then
    TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null) || true
    # Strip leading/trailing whitespace to prevent bypass via " sudo rm -rf /"
    TOOL_INPUT=$(printf '%s' "$TOOL_INPUT" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
elif [[ "$TOOL_NAME" == "Read" || "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]]; then
    TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null) || true
else
    TOOL_INPUT=""
fi

# Bash with no command is invalid — fall back to prompt
[[ "$TOOL_NAME" == "Bash" && -z "$TOOL_INPUT" ]] && exit 0

# Load deny and ask rules from settings.json
if [[ ! -f "$SETTINGS" ]]; then
    exit 0  # No settings = fall back to prompt
fi

# Validate that settings.json is parseable before extracting rules.
# If jq can't parse the file, fall back to prompt rather than silently
# approving everything with empty rule sets.
if ! jq empty "$SETTINGS" 2>/dev/null; then
    exit 0
fi

DENY_RULES=$(jq -r '.permissions.deny[]? // empty' "$SETTINGS" 2>/dev/null) || true
ASK_RULES=$(jq -r '.permissions.ask[]? // empty' "$SETTINGS" 2>/dev/null) || true

# Combine deny + ask rules (both block auto-approval)
ALL_BLOCK_RULES=$(printf '%s\n%s' "$DENY_RULES" "$ASK_RULES")

# Convert a settings.json glob pattern to ERE regex for [[ =~ ]].
# Uses placeholders to prevent sed passes from corrupting each other.
# Handles: **/ (directory globstar), ** (any path), * (single segment)
glob_to_regex() {
    local pattern="$1"
    local regex="$pattern"

    # Step 1: Replace glob tokens with placeholders BEFORE escaping
    # Handle trailing **  (e.g., **/.azure/**)
    regex=$(printf '%s' "$regex" | sed 's|\*\*$|___TRAILGLOB___|g')
    # Handle **/ (leading/mid directory globstar)
    regex=$(printf '%s' "$regex" | sed 's|\*\*/|___DIRGLOB___|g')
    # Handle remaining ** (shouldn't exist after above, but just in case)
    regex=$(printf '%s' "$regex" | sed 's|\*\*|___DOUBLEGLOB___|g')
    # Handle remaining single *
    regex=$(printf '%s' "$regex" | sed 's|\*|___SINGLEGLOB___|g')

    # Step 2: Escape regex special chars (dots only — glob patterns don't contain brackets/parens in path segments)
    # Note: BSD sed (macOS) can't use \( in patterns, so we only escape dots here.
    regex=$(printf '%s' "$regex" | sed 's/\./\\./g')

    # Step 3: Replace placeholders with ERE patterns
    # ___DIRGLOB___ = **/ = match any directory prefix (including none)
    # Use # as sed delimiter to avoid collision with | in replacement
    regex=$(printf '%s' "$regex" | sed 's#___DIRGLOB___#(^|.*/)#g')
    # ___TRAILGLOB___ = trailing ** = match anything after (including nothing)
    regex=$(printf '%s' "$regex" | sed 's#___TRAILGLOB___#.*#g')
    # ___DOUBLEGLOB___ = ** = match anything
    regex=$(printf '%s' "$regex" | sed 's#___DOUBLEGLOB___#.*#g')
    # ___SINGLEGLOB___ = * = match within one path segment (no slashes)
    regex=$(printf '%s' "$regex" | sed 's#___SINGLEGLOB___#[^/]*#g')

    # Anchor end
    regex="${regex}$"
    echo "$regex"
}

# Check if any block rule matches
BLOCKED=false

while IFS= read -r rule; do
    [[ -z "$rule" ]] && continue

    # Parse rule format: ToolName(pattern) or bare ToolName
    if [[ "$rule" =~ ^([A-Za-z]+)\((.+)\)$ ]]; then
        RULE_TOOL="${BASH_REMATCH[1]}"
        RULE_PATTERN="${BASH_REMATCH[2]}"
    elif [[ "$rule" =~ ^([A-Za-z]+)$ ]]; then
        RULE_TOOL="${BASH_REMATCH[1]}"
        RULE_PATTERN=""
    else
        continue
    fi

    # Skip rules for different tools.
    # Read/Write/Edit are treated as interchangeable for file-path deny rules:
    # a Read(**/.env*) deny rule also blocks Write and Edit on the same paths.
    FILE_PATH_TOOLS="Read Write Edit"
    if [[ "$RULE_TOOL" == "$TOOL_NAME" ]]; then
        : # exact match — always proceed
    elif [[ "$FILE_PATH_TOOLS" == *"$RULE_TOOL"* && "$FILE_PATH_TOOLS" == *"$TOOL_NAME"* ]]; then
        : # both are file-path tools — cross-match allowed
    else
        continue
    fi

    # Bare tool match (no pattern)
    if [[ -z "$RULE_PATTERN" ]]; then
        BLOCKED=true
        break
    fi

    # Match based on tool type
    if [[ "$TOOL_NAME" == "Bash" ]]; then
        # Simple glob matching for bash commands
        # shellcheck disable=SC2053
        if [[ "$TOOL_INPUT" == $RULE_PATTERN ]]; then
            BLOCKED=true
            break
        fi
    elif [[ -z "$TOOL_INPUT" ]]; then
        # Tool has a pattern rule but we couldn't extract its input.
        # Conservatively block to avoid silently bypassing deny rules.
        BLOCKED=true
        break
    else
        # Regex matching for file paths (handles **/ globstar)
        rule_regex=$(glob_to_regex "$RULE_PATTERN")
        if [[ "$TOOL_INPUT" =~ $rule_regex ]]; then
            BLOCKED=true
            break
        fi
    fi
done <<< "$ALL_BLOCK_RULES"

# If blocked by deny/ask rule, output nothing (fall back to prompt)
if [[ "$BLOCKED" == "true" ]]; then
    exit 0
fi

# Auto-approve: output the decision in hookSpecificOutput format
echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'

# Log the approval (atomic append, truncate input to 500 chars)
TRUNCATED_INPUT="${TOOL_INPUT:0:500}"
TS=$(date -u +%Y-%m-%dT%H:%M:%S)
jq -n -c \
    --arg ts "$TS" \
    --arg tool "$TOOL_NAME" \
    --arg input "$TRUNCATED_INPUT" \
    --arg reason "$REASON" \
    --arg decision "allow" \
    '{ts: $ts, tool: $tool, input: $input, reason: $reason, decision: $decision}' \
    >> "$LOG_FILE" 2>/dev/null || true

exit 0
