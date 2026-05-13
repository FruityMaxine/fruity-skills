#!/usr/bin/env bash
# fruity-skills · Stop hook
# 拦截 Claude 试图结束 turn 时, 强制调用 anti-slacking-auditor sub-agent 审核
#
# 行为:
#   1. 读 transcript_path 检测本 turn 是否涉及实质改动 (Write / Edit / Bash)
#   2. 检测本 turn 是否已经调用过 anti-slacking-auditor sub-agent
#   3. 若有改动 且 尚未审核 → block, 要求 Claude 调用 sub-agent
#   4. 若已审核 或 无改动 → 放行
#
# 输入: stdin JSON, 含 transcript_path / session_id / hook_event_name / stop_hook_active
# 输出: stdout JSON, decision=block 时 reason 注入提示

set -euo pipefail

INPUT=$(cat)

# stop_hook_active=true 表示 hook 已经 block 过一次后 Claude 又试图 Stop;
# 避免死循环, 放行
STOP_HOOK_ACTIVE=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("stop_hook_active", False))' 2>/dev/null || echo "False")
if [[ "$STOP_HOOK_ACTIVE" == "True" ]]; then
  echo '{}'
  exit 0
fi

TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("transcript_path",""))' 2>/dev/null || echo "")

if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  # 拿不到 transcript 就放行 (避免误杀)
  echo '{}'
  exit 0
fi

# 简单启发: transcript 末尾 N 行 (本 turn) 若含 Write/Edit/Bash 工具调用, 需审核
TAIL_CONTENT=$(tail -n 200 "$TRANSCRIPT_PATH" 2>/dev/null || echo "")

HAS_CODE_CHANGE=false
if printf '%s' "$TAIL_CONTENT" | grep -qE '"(Write|Edit|MultiEdit)"' ; then
  HAS_CODE_CHANGE=true
fi
if printf '%s' "$TAIL_CONTENT" | grep -qE '"Bash".*"command"' ; then
  HAS_CODE_CHANGE=true
fi

if [[ "$HAS_CODE_CHANGE" == "false" ]]; then
  # 本 turn 无代码改动, 放行
  echo '{}'
  exit 0
fi

# 检测本 turn 是否已经派发过 anti-slacking-auditor sub-agent
ALREADY_AUDITED=false
if printf '%s' "$TAIL_CONTENT" | grep -q 'anti-slacking-auditor' ; then
  ALREADY_AUDITED=true
fi

if [[ "$ALREADY_AUDITED" == "true" ]]; then
  echo '{}'
  exit 0
fi

# 阻断: 要求 Claude 调用 sub-agent
cat <<'EOF'
{
  "decision": "block",
  "reason": "[强制·fruity-skills 反偷懒守门] 本 turn 涉及代码 / 命令改动但尚未经 anti-slacking-auditor 审核,不能结束。\n\n现在你必须:\n1. 用 Agent 工具调用 subagent_type=\"anti-slacking-auditor\"\n2. prompt 中提供: (a) 用户本次原话 (b) 你声称做了什么 (c) 实际改了哪些文件\n3. 等待 auditor 返回 verdict (PASS / FAIL + 具体问题清单)\n4. FAIL → 立即按 auditor 清单修补,修完再次调用 auditor 复审,直到 PASS\n5. PASS → 简短告知用户审核已通过,然后才能结束 turn\n\n跳过 sub-agent 不允许。"
}
EOF
