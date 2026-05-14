#!/usr/bin/env bash
# fruity-skills · UserPromptSubmit hook · v0.14.0.0
#
# 写当前 epoch 到 /tmp/fruity-audit-<sid>.turn_start，供 stop-anti-slacking.sh 区分
# "本 turn 内真实 dirty" 与 "前 turn 异步残留 dirty"。
#
# Background: subagent (anti-slacking-auditor) 自身的 Bash 调用走 PostToolUse
# 触发 mark-dirty.sh，其异步落盘可能在父 Stop 清理之后，留下孤儿 dirty，
# 导致下一 turn 即便只跑只读命令也被误 block。
#
# Fix: stop-anti-slacking.sh 读本文件 mtime 与 dirty.mtime 比较，
# 若 dirty.mtime < turn_start → 视为前 turn 残留，自动清理放行。

set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')

SID=$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("session_id", ""))
except Exception:
    print("")
' 2>/dev/null)

[[ -z "$SID" ]] && exit 0

date +%s > "/tmp/fruity-audit-${SID}.turn_start" 2>/dev/null
exit 0
