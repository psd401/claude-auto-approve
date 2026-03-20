#!/usr/bin/env bash
# ABOUTME: Test harness for auto-approve-safe.sh
# ABOUTME: Feeds mock PermissionRequest JSON and checks output.

HOOK="$(dirname "$0")/auto-approve-safe.sh"
PASS=0
FAIL=0

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
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
