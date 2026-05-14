#!/usr/bin/env bash
# fruity-skills · Stop hook (v0.2.2.0)
# 绕过机制 (仅对非 BLOCKED 生效):
#   FRUITY_NO_AUDIT=1 env var / 用户原话含 [skip-audit]/别审了/跳过审核 / /tmp/fruity-audit-<sid>.skip flag

set -euo pipefail

INPUT=$(cat)

STOP_HOOK_ACTIVE=$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print(d.get("stop_hook_active", False))
except: print("False")' 2>/dev/null || echo "False")

if [[ "$STOP_HOOK_ACTIVE" == "True" ]]; then
  echo '{}'; exit 0
fi

SESSION_ID=$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print(d.get("session_id",""))
except: print("")' 2>/dev/null || echo "")

if [[ -z "$SESSION_ID" ]]; then
  echo '{}'; exit 0
fi

DIRTY="/tmp/fruity-audit-${SESSION_ID}.dirty"
AUDITED="/tmp/fruity-audit-${SESSION_ID}.audited"
SKIP_FLAG="/tmp/fruity-audit-${SESSION_ID}.skip"
HISTORY="/tmp/fruity-audit-history-${SESSION_ID}.json"
TURN_START="/tmp/fruity-audit-${SESSION_ID}.turn_start"

# 检 critical BLOCKED — 绕过对其无效
HAS_BLOCKED=$(python3 - <<PY 2>/dev/null || echo "false"
import json,os
h="$HISTORY"
if not os.path.exists(h):
    print("false"); raise SystemExit
try:
    d=json.loads(open(h).read())
    ticks=d.get("ticks",[])
    if ticks and ticks[-1].get("verdict")=="BLOCKED":
        print("true")
    else:
        print("false")
except Exception:
    print("false")
PY
)

if [[ "$HAS_BLOCKED" == "true" ]]; then
  cat <<'EOF'
{
  "decision": "block",
  "reason": "[强制·fruity-skills CRITICAL 红线未解决] 最近一次 audit 返回 BLOCKED (critical 维度 FAIL)。\n\n红线不计 iter 上限,绕过机制 (FRUITY_NO_AUDIT / [skip-audit] / .skip flag) 对 critical 全部失效。\n\n你必须: 读 /tmp/fruity-audit-history-<session>.json 看 Critical Blocks: 列表 → 逐项修复 → 再派 anti-slacking-auditor 复审 → 直到 verdict != BLOCKED 才能结束 turn"
}
EOF
  exit 0
fi

if [[ ! -f "$DIRTY" ]]; then
  echo '{}'; exit 0
fi

# Stale-dirty filter (v0.14.0.0): 清理前 turn 残留 dirty (subagent 异步落盘 leak)
# 若 dirty.mtime < turn_start → 视为前 turn 孤儿,自动清理放行
if [[ -f "$TURN_START" ]]; then
  TURN_START_TS=$(cat "$TURN_START" 2>/dev/null || echo 0)
  DIRTY_TS=$(stat -c %Y "$DIRTY" 2>/dev/null || echo 0)
  if (( DIRTY_TS < TURN_START_TS )); then
    rm -f "$DIRTY"
    echo '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"[fruity-skills] Cleaned stale dirty flag from prior turn (mtime older than turn_start)."}}'
    exit 0
  fi
fi

# 绕过 1: env var
if [[ "${FRUITY_NO_AUDIT:-}" == "1" ]]; then
  rm -f "$DIRTY" "$AUDITED" "$SKIP_FLAG"
  echo '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"[fruity-skills] Audit bypassed via FRUITY_NO_AUDIT=1."}}'
  exit 0
fi

# 绕过 2: skip flag
if [[ -f "$SKIP_FLAG" ]]; then
  rm -f "$DIRTY" "$AUDITED" "$SKIP_FLAG"
  echo '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"[fruity-skills] Audit bypassed via .skip flag."}}'
  exit 0
fi

# 绕过 3: 用户原话关键词
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print(d.get("transcript_path",""))
except: print("")' 2>/dev/null || echo "")

SKIP_BY_KEYWORD=false
if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
  LAST_USER=$(python3 - "$TRANSCRIPT_PATH" <<'PY' 2>/dev/null || echo ""
import json,sys
last=""
try:
    for line in open(sys.argv[1]):
        try: d=json.loads(line)
        except: continue
        if d.get("type")=="user" or d.get("role")=="user":
            c=d.get("message",{}).get("content","")
            if isinstance(c,str): last=c
            elif isinstance(c,list):
                last="\n".join([p.get("text","") for p in c if isinstance(p,dict)])
    print(last[-500:])
except Exception: print("")
PY
)
  if [[ -n "$LAST_USER" ]]; then
    if printf '%s' "$LAST_USER" | grep -qE '\[skip-audit\]|别审了|算了别审|不用审|跳过审核' ; then
      SKIP_BY_KEYWORD=true
    fi
  fi
fi

if [[ "$SKIP_BY_KEYWORD" == "true" ]]; then
  rm -f "$DIRTY" "$AUDITED"
  echo '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"[fruity-skills] Audit bypassed by user keyword."}}'
  exit 0
fi

if [[ -f "$AUDITED" ]]; then
  VERDICT=$(cat "$AUDITED" 2>/dev/null || echo "PASS")
  rm -f "$DIRTY" "$AUDITED"
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"Stop\",\"additionalContext\":\"[fruity-skills] Audit verdict: ${VERDICT}.\"}}"
  exit 0
fi

# 算本次 audit 之 diff range — 若上次 audited 标记之 commit 仍在 git 树内,
# 则覆盖自该 commit 至 HEAD 之全部未审 commit；否则 fallback HEAD~1。
# 解决主 Claude 一轮内打多个 commit 而 auditor 默认仅看 HEAD~1 之漏审 bug。
CWD=$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print(d.get("cwd",""))
except: print("")' 2>/dev/null || echo "")

LAST_AUDITED_COMMIT_FILE="/tmp/fruity-audit-${SESSION_ID}.last_audited_commit"
DIFF_RANGE="HEAD~1"
if [[ -f "$LAST_AUDITED_COMMIT_FILE" ]] && [[ -n "$CWD" ]] && [[ -d "$CWD" ]]; then
  LAST_SHA=$(head -c 40 "$LAST_AUDITED_COMMIT_FILE" 2>/dev/null || echo "")
  if [[ -n "$LAST_SHA" ]] && (cd "$CWD" && git rev-parse --verify "$LAST_SHA" >/dev/null 2>&1); then
    CURRENT_HEAD=$(cd "$CWD" && git rev-parse HEAD 2>/dev/null || echo "")
    if [[ -n "$CURRENT_HEAD" ]] && [[ "$CURRENT_HEAD" != "$LAST_SHA" ]]; then
      DIFF_RANGE="${LAST_SHA}..HEAD"
    fi
  fi
fi

# 注意: unquoted heredoc 会插值 — ${DIFF_RANGE} 实际替换, \${SESSION} 字面保留
cat <<EOF
{
  "decision": "block",
  "reason": "[强制·fruity-skills 反偷懒守门] 本 turn 涉及代码/命令改动 (PostToolUse 已记录 dirty flag), 但尚未经 anti-slacking-auditor 审核通过, 不能结束。\\n\\n你必须:\\n1. 用 Agent 工具调用 subagent_type=\"anti-slacking-auditor\"\\n2. prompt 中提供: (a) 用户本次原话 (b) 你声称做了什么 (c) \`git diff --stat ${DIFF_RANGE}\` 输出 (range 覆盖自上次 audited 通过以来全部未审 commit)\\n3. 报告结尾必须是 \`## Final Verdict: <PASS|PASS_WITH_DEBT|BLOCKED|FAIL> [iter N/3]\`\\n4. PASS / PASS_WITH_DEBT → audited flag 自动写, 可结束\\n5. FAIL → 按清单改再派 (iter +1)\\n6. BLOCKED (critical 红线) → 不计 iter 上限, 改到非 BLOCKED\\n\\n绕过 (非 BLOCKED 才有效): FRUITY_NO_AUDIT=1 / 用户说 \`[skip-audit]\`/\`别审了\`/\`跳过审核\` / \`touch /tmp/fruity-audit-\${SESSION}.skip\`。"
}
EOF
