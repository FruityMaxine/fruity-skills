#!/usr/bin/env bash
# fruity-skills · PostToolUse hook (matcher: Task)
# 作用: Task 工具结束后, 若 subagent_type == anti-slacking-auditor 且 audit 报告以
#       "## Final Verdict: PASS" 结尾, 写 audited flag; 否则不写 (FAIL 不算审过)
#
# 输入 stdin: JSON, 含 session_id / tool_name / tool_input.subagent_type / tool_response
# 输出: 静默

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')

python3 - <<PY
import json,sys,os,re
raw='''$INPUT'''
try:
    d=json.loads(raw)
except Exception:
    sys.exit(0)

session=d.get("session_id","")
if not session:
    sys.exit(0)

tinput=d.get("tool_input",{}) or {}
sub_type=tinput.get("subagent_type","")
if sub_type != "anti-slacking-auditor":
    sys.exit(0)

tresp=d.get("tool_response","") or ""
if isinstance(tresp, dict):
    parts=tresp.get("content",[])
    if isinstance(parts,list):
        text="\n".join([p.get("text","") if isinstance(p,dict) else str(p) for p in parts])
    else:
        text=str(parts)
else:
    text=str(tresp)

m=re.search(r"##\s*Final Verdict:\s*(PASS|FAIL)", text, re.IGNORECASE)
if not m:
    sys.exit(0)
verdict=m.group(1).upper()
if verdict != "PASS":
    sys.exit(0)

flag=f"/tmp/fruity-audit-{session}.audited"
open(flag,"w").write("PASS")
PY
exit 0
