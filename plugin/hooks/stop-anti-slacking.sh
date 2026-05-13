#!/usr/bin/env bash
# fruity-skills · Stop hook (v0.2.1.0 重写, 用 flag 文件替代 transcript grep)
#
# 与 PostToolUse hooks (mark-dirty / mark-audited) 配合:
#   - 本 turn 跑过 Write|Edit|MultiEdit|Bash → /tmp/fruity-audit-<sid>.dirty 存在
#   - anti-slacking-auditor PASS 返回   → /tmp/fruity-audit-<sid>.audited 存在
#
# 决策:
#   1. stop_hook_active=True → 已 block 过一次, 防死循环放行
#   2. 没 dirty → 本 turn 无改动, 放行
#   3. 有 dirty 且有 audited → 已审过, 清两个 flag, 放行
#   4. 有 dirty 但没 audited → block, 要求主 Claude 调用 anti-slacking-auditor
#
# 这种 flag 方案比 grep transcript 准确:
#   - 工具调用必经 PostToolUse hook (结构化判断, 非文本匹配)
#   - audited flag 只在 Final Verdict: PASS 时才写 (FAIL 不算审过)
#   - 避免讨论"Write/Edit/Bash"文本被误判为"有改动"
#   - 避免长 turn transcript 超 200 行被截断漏判

set -euo pipefail

INPUT=$(cat)

STOP_HOOK_ACTIVE=$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print(d.get("stop_hook_active", False))
except: print("False")' 2>/dev/null || echo "False")

if [[ "$STOP_HOOK_ACTIVE" == "True" ]]; then
  echo '{}'
  exit 0
fi

SESSION_ID=$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print(d.get("session_id",""))
except: print("")' 2>/dev/null || echo "")

if [[ -z "$SESSION_ID" ]]; then
  # 拿不到 session_id, 放行避免误杀
  echo '{}'
  exit 0
fi

DIRTY="/tmp/fruity-audit-${SESSION_ID}.dirty"
AUDITED="/tmp/fruity-audit-${SESSION_ID}.audited"

if [[ ! -f "$DIRTY" ]]; then
  # 本 turn 无代码改动, 放行
  echo '{}'
  exit 0
fi

if [[ -f "$AUDITED" ]]; then
  # 已审过, 清两个 flag (本 turn 结束), 放行
  rm -f "$DIRTY" "$AUDITED"
  echo '{}'
  exit 0
fi

# dirty 但未审 → block
cat <<'EOF'
{
  "decision": "block",
  "reason": "[强制·fruity-skills 反偷懒守门] 本 turn 涉及代码/命令改动 (PostToolUse 已记录 dirty flag), 但尚未经 anti-slacking-auditor 审核通过, 不能结束。\n\n现在你必须:\n1. 用 Agent 工具调用 subagent_type=\"anti-slacking-auditor\"\n2. prompt 中提供: (a) 用户本次原话 (b) 你声称做了什么 (c) 实际改了哪些文件 (用 git diff --stat 列)\n3. 等待 auditor 返回, 检查报告结尾必须是 `## Final Verdict: PASS` 或 `FAIL`\n4. FAIL → 按 auditor 清单立即修补, 修完再次调用 auditor 复审, 直到 PASS\n5. PASS → auditor 返回时 PostToolUse hook 自动写 audited flag, 你可以结束 turn\n\n跳过 sub-agent 不允许。fruity-skills v0.2.1.0 用 PostToolUse flag 结构化判断, 不再依赖 transcript grep, 误判率 ~0。"
}
EOF
