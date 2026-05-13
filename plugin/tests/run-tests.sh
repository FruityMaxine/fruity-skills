#!/usr/bin/env bash
# fruity-skills · 端到端 hook 测试套件
# 用法: bash plugin/tests/run-tests.sh
# 退出码: 0 全过, 非 0 = 失败数

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS="$SCRIPT_DIR/../hooks"
TEST_SID="test-session-$(date +%s)-$$"
CWD_TMP=$(mktemp -d)
trap "rm -rf $CWD_TMP /tmp/fruity-audit-${TEST_SID}.* /tmp/fruity-audit-history-${TEST_SID}.json" EXIT

# 初始化 mock git repo (Step 1 git diff 要用)
cd "$CWD_TMP"
git init -q
git config user.email "t@t"
git config user.name "T"
echo "v1" > VERSION
git add . && git commit -q -m "init"

PASS=0
FAIL=0
RED=$'\033[0;31m'
GRN=$'\033[0;32m'
RST=$'\033[0m'

assert() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "${GRN}PASS${RST}: $name"
    PASS=$((PASS+1))
  else
    echo "${RED}FAIL${RST}: $name"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    FAIL=$((FAIL+1))
  fi
}

mock_input() {
  local extra="$1"
  cat <<EOF
{
  "session_id": "$TEST_SID",
  "cwd": "$CWD_TMP",
  "transcript_path": "$CWD_TMP/transcript.jsonl",
  "hook_event_name": "test",
  $extra
}
EOF
}

cleanup_flags() {
  rm -f "/tmp/fruity-audit-${TEST_SID}".* "/tmp/fruity-audit-history-${TEST_SID}.json"
}

echo "=== fruity-skills hook 测试 (session=$TEST_SID) ==="

# Test 1: skill-match-announcer 输出含 [ACK] 和 [SkillMatch] 关键词
out=$(echo '{}' | bash "$HOOKS/skill-match-announcer.sh" 2>/dev/null)
has_ack=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); ctx=d.get("hookSpecificOutput",{}).get("additionalContext",""); print("yes" if "[ACK]" in ctx and "[SkillMatch]" in ctx else "no")' 2>/dev/null)
assert "skill-match-announcer 注入 [ACK]+[SkillMatch]" "yes" "$has_ack"

# Test 2: post-tool-mark-dirty 在 Write 后写 dirty flag
cleanup_flags
mock_input '"tool_name":"Write","tool_input":{"file_path":"foo"}' | bash "$HOOKS/post-tool-mark-dirty.sh" 2>/dev/null
if [[ -f "/tmp/fruity-audit-${TEST_SID}.dirty" ]]; then
  assert "post-tool-mark-dirty 写 .dirty" "yes" "yes"
else
  assert "post-tool-mark-dirty 写 .dirty" "yes" "no"
fi

# Test 3: post-tool-mark-audited 在 anti-slacking-auditor PASS 时写 .audited + history
cleanup_flags
mock_input '"tool_name":"Task","tool_input":{"subagent_type":"anti-slacking-auditor"},"tool_response":{"content":[{"text":"## Anti-Slacking Audit\n## Fail Dimensions: []\n## Final Verdict: PASS [iter 1/3]"}]}' | bash "$HOOKS/post-tool-mark-audited.sh" 2>/dev/null
if [[ -f "/tmp/fruity-audit-${TEST_SID}.audited" ]]; then
  v=$(cat "/tmp/fruity-audit-${TEST_SID}.audited")
  assert "post-tool-mark-audited PASS 写 .audited" "PASS" "$v"
else
  assert "post-tool-mark-audited PASS 写 .audited" "PASS" "missing"
fi
if [[ -f "/tmp/fruity-audit-history-${TEST_SID}.json" ]]; then
  cnt=$(jq '.ticks | length' "/tmp/fruity-audit-history-${TEST_SID}.json" 2>/dev/null)
  assert "post-tool-mark-audited 追加 history.json" "1" "$cnt"
else
  assert "post-tool-mark-audited 追加 history.json" "1" "missing"
fi

# Test 4: post-tool-mark-audited 在 FAIL 时不写 .audited 但写 history
cleanup_flags
mock_input '"tool_name":"Task","tool_input":{"subagent_type":"anti-slacking-auditor"},"tool_response":{"content":[{"text":"## Fail Dimensions: [VERSION_BUMP]\n## Final Verdict: FAIL [iter 1/3]"}]}' | bash "$HOOKS/post-tool-mark-audited.sh" 2>/dev/null
if [[ -f "/tmp/fruity-audit-${TEST_SID}.audited" ]]; then
  assert "post-tool-mark-audited FAIL 不写 .audited" "no" "yes"
else
  assert "post-tool-mark-audited FAIL 不写 .audited" "no" "no"
fi
if [[ -f "/tmp/fruity-audit-history-${TEST_SID}.json" ]]; then
  v=$(jq -r '.ticks[0].verdict' "/tmp/fruity-audit-history-${TEST_SID}.json" 2>/dev/null)
  assert "post-tool-mark-audited FAIL 记入 history" "FAIL" "$v"
else
  assert "post-tool-mark-audited FAIL 记入 history" "FAIL" "missing"
fi

# Test 5: post-tool-mark-audited 在非 anti-slacking-auditor sub-agent 不动 flag
cleanup_flags
mock_input '"tool_name":"Task","tool_input":{"subagent_type":"some-other-agent"},"tool_response":{"content":[{"text":"## Final Verdict: PASS"}]}' | bash "$HOOKS/post-tool-mark-audited.sh" 2>/dev/null
if [[ -f "/tmp/fruity-audit-${TEST_SID}.audited" ]] || [[ -f "/tmp/fruity-audit-history-${TEST_SID}.json" ]]; then
  assert "其他 sub-agent 不影响 flag/history" "no" "yes"
else
  assert "其他 sub-agent 不影响 flag/history" "no" "no"
fi

# Test 6: Stop hook 在无 dirty 时放行 (空 JSON output)
cleanup_flags
out=$(mock_input '"stop_hook_active":false' | bash "$HOOKS/stop-anti-slacking.sh" 2>/dev/null)
decision=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision","none"))' 2>/dev/null)
assert "Stop 无 dirty 放行" "none" "$decision"

# Test 7: Stop hook 在有 dirty 无 audited 时 block
cleanup_flags
touch "/tmp/fruity-audit-${TEST_SID}.dirty"
out=$(mock_input '"stop_hook_active":false' | bash "$HOOKS/stop-anti-slacking.sh" 2>/dev/null)
decision=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision","none"))' 2>/dev/null)
assert "Stop dirty 无 audited 应 block" "block" "$decision"

# Test 8: Stop hook 在 dirty + audited 时放行 + 清 flag
cleanup_flags
touch "/tmp/fruity-audit-${TEST_SID}.dirty"
echo "PASS" > "/tmp/fruity-audit-${TEST_SID}.audited"
out=$(mock_input '"stop_hook_active":false' | bash "$HOOKS/stop-anti-slacking.sh" 2>/dev/null)
decision=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision","none"))' 2>/dev/null)
assert "Stop dirty+audited 放行" "none" "$decision"
if [[ -f "/tmp/fruity-audit-${TEST_SID}.dirty" ]] || [[ -f "/tmp/fruity-audit-${TEST_SID}.audited" ]]; then
  assert "Stop 放行后清 flag" "cleaned" "not-cleaned"
else
  assert "Stop 放行后清 flag" "cleaned" "cleaned"
fi

# Test 9: Stop hook 在 history 末 BLOCKED 时永拦
cleanup_flags
touch "/tmp/fruity-audit-${TEST_SID}.dirty"
echo "PASS" > "/tmp/fruity-audit-${TEST_SID}.audited"
cat > "/tmp/fruity-audit-history-${TEST_SID}.json" <<HJSON
{"session":"$TEST_SID","ticks":[{"tick":1,"verdict":"BLOCKED","fail_dims":["NO_CO_AUTHOR"]}]}
HJSON
out=$(mock_input '"stop_hook_active":false' | bash "$HOOKS/stop-anti-slacking.sh" 2>/dev/null)
decision=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision","none"))' 2>/dev/null)
assert "Stop BLOCKED 永拦 (即使有 audited)" "block" "$decision"

# Test 10: Stop hook FRUITY_NO_AUDIT=1 绕过 (非 BLOCKED)
cleanup_flags
touch "/tmp/fruity-audit-${TEST_SID}.dirty"
out=$(FRUITY_NO_AUDIT=1 bash -c "cat <<JSON | bash '$HOOKS/stop-anti-slacking.sh'
$(mock_input '\"stop_hook_active\":false')
JSON" 2>/dev/null)
decision=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision","none"))' 2>/dev/null)
assert "Stop FRUITY_NO_AUDIT=1 绕过 (非 BLOCKED)" "none" "$decision"

# Test 11: Stop hook 在 .skip flag 时绕过
cleanup_flags
touch "/tmp/fruity-audit-${TEST_SID}.dirty"
touch "/tmp/fruity-audit-${TEST_SID}.skip"
out=$(mock_input '"stop_hook_active":false' | bash "$HOOKS/stop-anti-slacking.sh" 2>/dev/null)
decision=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision","none"))' 2>/dev/null)
assert "Stop .skip flag 绕过" "none" "$decision"

# Test 12: stop_hook_active=true 防死循环
cleanup_flags
touch "/tmp/fruity-audit-${TEST_SID}.dirty"
out=$(mock_input '"stop_hook_active":true' | bash "$HOOKS/stop-anti-slacking.sh" 2>/dev/null)
decision=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision","none"))' 2>/dev/null)
assert "Stop stop_hook_active=true 防死循环" "none" "$decision"

# ===== PreToolUse 红线测试 =====

# Test 13: 红线 Bash git commit Co-Authored-By → block
out=$(echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"feat\\n\\nCo-Authored-By: Claude <c@a.com>\""}}' | bash "$HOOKS/pre-tool-critical-redline.sh" 2>/dev/null)
decision=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision","none"))' 2>/dev/null)
assert "PreTool 红线 Co-Authored-By 拦截" "block" "$decision"

# Test 14: 红线 Write bind 0.0.0.0 → block
out=$(echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/x.conf","content":"listen 0.0.0.0:8080"}}' | bash "$HOOKS/pre-tool-critical-redline.sh" 2>/dev/null)
decision=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision","none"))' 2>/dev/null)
assert "PreTool 红线 bind 0.0.0.0 拦截" "block" "$decision"

# Test 15: 红线 GitHub token → block
out=$(echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/c.py","content":"K=\"ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\""}}' | bash "$HOOKS/pre-tool-critical-redline.sh" 2>/dev/null)
decision=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision","none"))' 2>/dev/null)
assert "PreTool 红线 GitHub token 拦截" "block" "$decision"

# Test 16: 红线 systemd 行尾中文注释 → block
out=$(printf '{"tool_name":"Write","tool_input":{"file_path":"/etc/systemd/system/foo.service","content":"[Service]\\nMemoryMax=1G    # 中文\\n"}}' | bash "$HOOKS/pre-tool-critical-redline.sh" 2>/dev/null)
decision=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision","none"))' 2>/dev/null)
assert "PreTool 红线 systemd 行尾中文注释拦截" "block" "$decision"

# Test 17: 红线 rm -rf / → block
out=$(echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | bash "$HOOKS/pre-tool-critical-redline.sh" 2>/dev/null)
decision=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision","none"))' 2>/dev/null)
assert "PreTool 红线 rm -rf / 拦截" "block" "$decision"

# Test 18: 正常 Bash ls 应放行
out=$(echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | bash "$HOOKS/pre-tool-critical-redline.sh" 2>/dev/null)
decision=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision","none"))' 2>/dev/null || echo "none")
assert "PreTool 正常 ls 放行" "none" "$decision"

# Test 19: 正常 Write markdown 应放行
out=$(echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/x.md","content":"# Hello\nworld"}}' | bash "$HOOKS/pre-tool-critical-redline.sh" 2>/dev/null)
decision=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision","none"))' 2>/dev/null || echo "none")
assert "PreTool 正常 markdown 放行" "none" "$decision"

# Test 20: 红线 Edit new_string 含 bind 0.0.0.0 → block
out=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/cfg.toml","old_string":"x","new_string":"bind = \"0.0.0.0\""}}' | bash "$HOOKS/pre-tool-critical-redline.sh" 2>/dev/null)
decision=$(echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision","none"))' 2>/dev/null)
assert "PreTool 红线 Edit new_string 含 bind 0.0.0.0 拦截" "block" "$decision"

# 汇总
echo ""
echo "=== 结果: $PASS pass / $FAIL fail ==="
exit $FAIL
