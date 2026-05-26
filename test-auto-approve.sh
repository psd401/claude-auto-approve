#!/usr/bin/env bash
# ABOUTME: Test harness for auto-approve-safe.sh
# ABOUTME: Feeds mock PermissionRequest JSON and checks output.

HOOK="$(dirname "$0")/auto-approve-safe.sh"
PASS=0
FAIL=0
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

assert_approve() {
    local desc="$1"
    local json="$2"
    local output
    output=$(echo "$json" | "$HOOK" 2>/dev/null)
    if echo "$output" | grep -q '"allow"'; then
        ((PASS++))
        echo "  PASS: $desc"
    else
        ((FAIL++))
        echo "  FAIL: $desc (expected allow, got: '$output')"
    fi
}

assert_prompt() {
    local desc="$1"
    local json="$2"
    local output
    output=$(echo "$json" | "$HOOK" 2>/dev/null)
    if [[ -z "$output" ]] || ! echo "$output" | grep -q '"allow"'; then
        ((PASS++))
        echo "  PASS: $desc"
    else
        ((FAIL++))
        echo "  FAIL: $desc (expected no output/prompt, got: '$output')"
    fi
}

assert_approve_with_settings() {
    local desc="$1"
    local json="$2"
    local settings_file="$3"
    local output
    output=$(echo "$json" | CLAUDE_SETTINGS="$settings_file" "$HOOK" 2>/dev/null)
    if echo "$output" | grep -q '"allow"'; then
        ((PASS++))
        echo "  PASS: $desc"
    else
        ((FAIL++))
        echo "  FAIL: $desc (expected allow, got: '$output')"
    fi
}

assert_prompt_with_settings() {
    local desc="$1"
    local json="$2"
    local settings_file="$3"
    local output
    output=$(echo "$json" | CLAUDE_SETTINGS="$settings_file" "$HOOK" 2>/dev/null)
    if [[ -z "$output" ]] || ! echo "$output" | grep -q '"allow"'; then
        ((PASS++))
        echo "  PASS: $desc"
    else
        ((FAIL++))
        echo "  FAIL: $desc (expected no output/prompt, got: '$output')"
    fi
}

echo "=== auto-approve-safe.sh tests ==="
echo ""
echo "--- Bash: should approve (heuristic false positives) ---"

assert_approve "compound && with echo" \
    '{"tool_name":"Bash","tool_input":{"command":"git log --oneline -10 && echo \"---\" && ls -la scripts/"},"reason":"Command contains quoted characters in flag names"}'

assert_approve "simple allowed command" \
    '{"tool_name":"Bash","tool_input":{"command":"bun test"},"reason":"Command contains quoted characters in flag names"}'

assert_approve "command substitution" \
    '{"tool_name":"Bash","tool_input":{"command":"echo $(date)"},"reason":"Command uses command substitution"}'

echo ""
echo "--- Bash: should prompt (deny rules) ---"

assert_prompt "sudo" \
    '{"tool_name":"Bash","tool_input":{"command":"sudo ls /root"},"reason":"unrecognized command"}'

assert_prompt "rm -rf" \
    '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/test"},"reason":"unrecognized command"}'

assert_prompt "rm -fr variant" \
    '{"tool_name":"Bash","tool_input":{"command":"rm -fr /tmp/test"},"reason":"unrecognized command"}'

assert_prompt "git reset --hard" \
    '{"tool_name":"Bash","tool_input":{"command":"git reset --hard HEAD~1"},"reason":"unrecognized command"}'

assert_prompt "git push --force" \
    '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"},"reason":"unrecognized command"}'

assert_prompt "git push -f" \
    '{"tool_name":"Bash","tool_input":{"command":"git push -f origin main"},"reason":"unrecognized command"}'

assert_prompt "truncate" \
    '{"tool_name":"Bash","tool_input":{"command":"truncate -s 0 /tmp/test"},"reason":"unrecognized command"}'

assert_prompt "dd if=/dev/zero" \
    '{"tool_name":"Bash","tool_input":{"command":"dd if=/dev/zero of=/tmp/disk bs=1M count=100"},"reason":"unrecognized command"}'

assert_prompt "chmod 777" \
    '{"tool_name":"Bash","tool_input":{"command":"chmod 777 /tmp/test"},"reason":"unrecognized command"}'

assert_prompt "nc -l" \
    '{"tool_name":"Bash","tool_input":{"command":"nc -l 8080"},"reason":"unrecognized command"}'

echo ""
echo "--- Bash: should prompt (ask rules) ---"

assert_prompt "git push" \
    '{"tool_name":"Bash","tool_input":{"command":"git push origin main"},"reason":"unrecognized command"}'

assert_prompt "rm (non-rf)" \
    '{"tool_name":"Bash","tool_input":{"command":"rm /tmp/somefile"},"reason":"unrecognized command"}'

echo ""
echo "--- Read: should prompt (deny rules for secrets) ---"

assert_prompt "Read .env" \
    '{"tool_name":"Read","tool_input":{"file_path":"/Users/HerberR_1/code/myproject/.env.local"},"reason":"file outside project"}'

assert_prompt "Read .pem" \
    '{"tool_name":"Read","tool_input":{"file_path":"/Users/HerberR_1/.ssh/server.pem"},"reason":"file outside project"}'

assert_prompt "Read .aws/credentials" \
    '{"tool_name":"Read","tool_input":{"file_path":"/Users/HerberR_1/.aws/credentials"},"reason":"file outside project"}'

assert_prompt "Read .docker/config.json" \
    '{"tool_name":"Read","tool_input":{"file_path":"/Users/HerberR_1/.docker/config.json"},"reason":"file outside project"}'

assert_prompt "Read .azure dir" \
    '{"tool_name":"Read","tool_input":{"file_path":"/Users/HerberR_1/.azure/tokens.json"},"reason":"file outside project"}'

assert_prompt "Read .kube/config" \
    '{"tool_name":"Read","tool_input":{"file_path":"/Users/HerberR_1/.kube/config"},"reason":"file outside project"}'

assert_prompt "Read id_rsa" \
    '{"tool_name":"Read","tool_input":{"file_path":"/Users/HerberR_1/.ssh/id_rsa"},"reason":"file outside project"}'

assert_prompt "Read secrets dir" \
    '{"tool_name":"Read","tool_input":{"file_path":"/Users/HerberR_1/code/myproject/secrets/api_key.txt"},"reason":"file outside project"}'

echo ""
echo "--- Edit: should prompt (deny rules cross-apply to Write/Edit) ---"

assert_prompt "Edit .env" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/Users/HerberR_1/code/myproject/.env.local"},"reason":"file outside project"}'

assert_prompt "Edit .pem" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/Users/HerberR_1/.ssh/server.pem"},"reason":"file outside project"}'

assert_prompt "Edit secrets dir" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/Users/HerberR_1/code/myproject/secrets/api_key.txt"},"reason":"file outside project"}'

assert_prompt "Edit id_rsa" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/Users/HerberR_1/.ssh/id_rsa"},"reason":"file outside project"}'

echo ""
echo "--- Write: should prompt (deny rules cross-apply to Write/Edit) ---"

assert_prompt "Write .env" \
    '{"tool_name":"Write","tool_input":{"file_path":"/Users/HerberR_1/code/myproject/.env.local"},"reason":"file outside project"}'

assert_prompt "Write .aws/credentials" \
    '{"tool_name":"Write","tool_input":{"file_path":"/Users/HerberR_1/.aws/credentials"},"reason":"file outside project"}'

assert_prompt "Write secrets dir" \
    '{"tool_name":"Write","tool_input":{"file_path":"/Users/HerberR_1/code/myproject/secrets/api_key.txt"},"reason":"file outside project"}'

echo ""
echo "--- Edit/Write: should approve (safe files) ---"

assert_approve "Edit normal source file" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/Users/HerberR_1/code/informacastmcp/src/index.ts"},"reason":"file outside project"}'

assert_approve "Write normal source file" \
    '{"tool_name":"Write","tool_input":{"file_path":"/Users/HerberR_1/code/informacastmcp/src/index.ts"},"reason":"file outside project"}'

echo ""
echo "--- Read: should approve (safe files) ---"

assert_approve "Read normal source file" \
    '{"tool_name":"Read","tool_input":{"file_path":"/Users/HerberR_1/code/informacastmcp/src/index.ts"},"reason":"file outside project"}'

assert_approve "Read package.json" \
    '{"tool_name":"Read","tool_input":{"file_path":"/Users/HerberR_1/code/informacastmcp/package.json"},"reason":"file outside project"}'

echo ""
echo "--- Other tools: should approve ---"

assert_approve "Glob" \
    '{"tool_name":"Glob","tool_input":{"pattern":"**/*.ts"},"reason":"some heuristic"}'

assert_approve "Grep" \
    '{"tool_name":"Grep","tool_input":{"pattern":"TODO"},"reason":"some heuristic"}'

assert_approve "WebSearch" \
    '{"tool_name":"WebSearch","tool_input":{"query":"bash glob matching"},"reason":"some heuristic"}'

echo ""
echo "--- Bash: should prompt (whitespace bypass prevention, SEC-001) ---"

assert_prompt "leading space on sudo" \
    '{"tool_name":"Bash","tool_input":{"command":" sudo ls /root"},"reason":"unrecognized command"}'

assert_prompt "leading tabs on rm -rf" \
    '{"tool_name":"Bash","tool_input":{"command":"\trm -rf /tmp/test"},"reason":"unrecognized command"}'

assert_prompt "trailing space on sudo" \
    '{"tool_name":"Bash","tool_input":{"command":"sudo ls /root  "},"reason":"unrecognized command"}'

echo ""
echo "--- Malformed input: should prompt (TEST-001) ---"

assert_prompt "invalid JSON input" \
    '{malformed json'

assert_prompt "empty input" \
    ''

assert_prompt "non-JSON string" \
    'this is not json at all'

echo ""
echo "--- Missing settings.json: should prompt (TEST-002) ---"

assert_prompt_with_settings "missing settings file" \
    '{"tool_name":"Bash","tool_input":{"command":"bun test"},"reason":"test"}' \
    "/tmp/nonexistent-settings-$(date +%s).json"

echo ""
echo "--- Malformed settings.json: should prompt (COR-001) ---"

MALFORMED_SETTINGS="$TMPDIR_TEST/malformed-settings.json"
echo '{invalid json content' > "$MALFORMED_SETTINGS"

assert_prompt_with_settings "malformed settings falls back to prompt" \
    '{"tool_name":"Bash","tool_input":{"command":"bun test"},"reason":"test"}' \
    "$MALFORMED_SETTINGS"

assert_prompt_with_settings "malformed settings blocks sudo" \
    '{"tool_name":"Bash","tool_input":{"command":"sudo rm -rf /"},"reason":"test"}' \
    "$MALFORMED_SETTINGS"

echo ""
echo "--- Valid settings with no deny/ask keys: should approve (TEST-002 edge) ---"

EMPTY_RULES_SETTINGS="$TMPDIR_TEST/empty-rules-settings.json"
echo '{"permissions":{}}' > "$EMPTY_RULES_SETTINGS"

assert_approve_with_settings "no deny/ask keys = approve" \
    '{"tool_name":"Bash","tool_input":{"command":"bun test"},"reason":"test"}' \
    "$EMPTY_RULES_SETTINGS"

echo ""
echo "--- Malformed rules in settings: should still process valid rules (TEST-004) ---"

MIXED_RULES_SETTINGS="$TMPDIR_TEST/mixed-rules-settings.json"
cat > "$MIXED_RULES_SETTINGS" <<'SETTINGSEOF'
{"permissions":{"deny":["Bash(sudo *)","not a valid rule!!!","Bash(rm -rf *)"],"ask":[]}}
SETTINGSEOF

assert_prompt_with_settings "valid rule after malformed rule still blocks" \
    '{"tool_name":"Bash","tool_input":{"command":"sudo ls /root"},"reason":"test"}' \
    "$MIXED_RULES_SETTINGS"

assert_prompt_with_settings "second valid rule after malformed rule still blocks" \
    '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/test"},"reason":"test"}' \
    "$MIXED_RULES_SETTINGS"

assert_approve_with_settings "non-matching command still approved" \
    '{"tool_name":"Bash","tool_input":{"command":"ls -la"},"reason":"test"}' \
    "$MIXED_RULES_SETTINGS"

echo ""
echo "--- glob_to_regex edge cases via file paths (TEST-003) ---"

GLOB_SETTINGS="$TMPDIR_TEST/glob-settings.json"
cat > "$GLOB_SETTINGS" <<'SETTINGSEOF'
{"permissions":{"deny":["Read(**/.env*)","Read(**/*.pem)","Read(**/secrets/**)"],"ask":[]}}
SETTINGSEOF

assert_prompt_with_settings "nested .env file" \
    '{"tool_name":"Read","tool_input":{"file_path":"/a/b/c/d/.env.local"},"reason":"test"}' \
    "$GLOB_SETTINGS"

assert_prompt_with_settings ".env at root" \
    '{"tool_name":"Read","tool_input":{"file_path":"/.env"},"reason":"test"}' \
    "$GLOB_SETTINGS"

assert_prompt_with_settings "deeply nested .pem" \
    '{"tool_name":"Read","tool_input":{"file_path":"/home/user/certs/sub/server.pem"},"reason":"test"}' \
    "$GLOB_SETTINGS"

assert_prompt_with_settings "secrets with trailing globstar" \
    '{"tool_name":"Read","tool_input":{"file_path":"/home/user/secrets/deep/nested/key.txt"},"reason":"test"}' \
    "$GLOB_SETTINGS"

assert_approve_with_settings "non-matching path approved" \
    '{"tool_name":"Read","tool_input":{"file_path":"/home/user/code/index.ts"},"reason":"test"}' \
    "$GLOB_SETTINGS"

echo ""
echo "--- Cross-tool isolation (TEST-006) ---"

CROSS_SETTINGS="$TMPDIR_TEST/cross-settings.json"
cat > "$CROSS_SETTINGS" <<'SETTINGSEOF'
{"permissions":{"deny":["Bash(sudo *)","Read(**/.env*)"],"ask":[]}}
SETTINGSEOF

assert_approve_with_settings "Bash rule does not block Read" \
    '{"tool_name":"Read","tool_input":{"file_path":"/usr/bin/sudo"},"reason":"test"}' \
    "$CROSS_SETTINGS"

assert_approve_with_settings "Read rule does not block Bash" \
    '{"tool_name":"Bash","tool_input":{"command":"cat .env.local"},"reason":"test"}' \
    "$CROSS_SETTINGS"

assert_prompt_with_settings "Read rule does cross-apply to Edit" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/home/user/.env.local"},"reason":"test"}' \
    "$CROSS_SETTINGS"

echo ""
echo "--- Empty command/file_path (TEST-009, TEST-010) ---"

assert_prompt "Bash with empty command" \
    '{"tool_name":"Bash","tool_input":{"command":""},"reason":"test"}'

assert_prompt "Bash with missing command key" \
    '{"tool_name":"Bash","tool_input":{},"reason":"test"}'

assert_prompt "Read with empty file_path" \
    '{"tool_name":"Read","tool_input":{"file_path":""},"reason":"test"}'

assert_prompt "Edit with missing file_path key" \
    '{"tool_name":"Edit","tool_input":{},"reason":"test"}'

echo ""
echo "--- Bash glob edge cases (TEST-005) ---"

GLOB_BASH_SETTINGS="$TMPDIR_TEST/glob-bash-settings.json"
cat > "$GLOB_BASH_SETTINGS" <<'SETTINGSEOF'
{"permissions":{"deny":["Bash(rm -rf *)","Bash(sudo *)"],"ask":["Bash(rm *)"]}}
SETTINGSEOF

assert_prompt_with_settings "rm -rf with path" \
    '{"tool_name":"Bash","tool_input":{"command":"rm -rf /important/data"},"reason":"test"}' \
    "$GLOB_BASH_SETTINGS"

assert_prompt_with_settings "sudo with complex args" \
    '{"tool_name":"Bash","tool_input":{"command":"sudo bash -c \"echo hello\""},"reason":"test"}' \
    "$GLOB_BASH_SETTINGS"

assert_approve_with_settings "rm without args (no glob match on rm -rf)" \
    '{"tool_name":"Bash","tool_input":{"command":"echo rm -rf is dangerous"},"reason":"test"}' \
    "$GLOB_BASH_SETTINGS"

echo ""
echo "--- Log file verification (TEST-008) ---"

LOG_TEST_FILE="$TMPDIR_TEST/test-permissions.log"
LOG_SETTINGS="$TMPDIR_TEST/log-settings.json"
echo '{"permissions":{"deny":[],"ask":[]}}' > "$LOG_SETTINGS"

echo '{"tool_name":"Bash","tool_input":{"command":"echo hello"},"reason":"test log"}' | \
    CLAUDE_SETTINGS="$LOG_SETTINGS" CLAUDE_PERMISSIONS_LOG="$LOG_TEST_FILE" "$HOOK" >/dev/null 2>&1

if [[ -f "$LOG_TEST_FILE" ]] && jq empty "$LOG_TEST_FILE" 2>/dev/null; then
    LOG_TOOL=$(jq -r '.tool' "$LOG_TEST_FILE" 2>/dev/null)
    LOG_INPUT=$(jq -r '.input' "$LOG_TEST_FILE" 2>/dev/null)
    if [[ "$LOG_TOOL" == "Bash" && "$LOG_INPUT" == "echo hello" ]]; then
        ((PASS++))
        echo "  PASS: log file created with valid JSON and correct fields"
    else
        ((FAIL++))
        echo "  FAIL: log file has wrong content (tool=$LOG_TOOL, input=$LOG_INPUT)"
    fi
else
    ((FAIL++))
    echo "  FAIL: log file not created or invalid JSON"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
