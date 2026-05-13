#!/usr/bin/env bash
# fruity-skills · PostToolUse hook (matcher: Write|Edit|MultiEdit|Bash)
# 作用: 工具调用成功后, 写一个 session 级 dirty flag, 标记"本 turn 有代码/命令改动"
# Stop hook 读这个 flag 决定是否要求 anti-slacking-auditor 审核
#
# 输入 stdin: JSON, 含 session_id / tool_name / tool_input / tool_response / hook_event_name
# 输出: 静默 (退出码 0)

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
SESSION_ID=$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print(d.get("session_id",""))
except: print("")' 2>/dev/null || echo "")

[[ -z "$SESSION_ID" ]] && exit 0

FLAG="/tmp/fruity-audit-${SESSION_ID}.dirty"
touch "$FLAG"
exit 0
