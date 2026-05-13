#!/usr/bin/env bash
# fruity-skills · PostToolUse hook (matcher: Task) · v0.2.2.0

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')

python3 - <<PY
import json,sys,os,re,subprocess,time
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

mv=re.search(r"##\s*Final Verdict:\s*(PASS_WITH_DEBT|PASS|BLOCKED|FAIL)\s*(?:\[iter\s*(\d+)/(?:3|\\u221e|∞)\])?",
             text, re.IGNORECASE)
if not mv:
    sys.exit(0)
verdict=mv.group(1).upper()
iter_n=int(mv.group(2)) if mv.group(2) else 1

mf=re.search(r"##\s*Fail Dimensions:\s*\[(.*?)\]", text)
fail_dims=[]
if mf:
    raw_dims=mf.group(1).strip()
    if raw_dims:
        fail_dims=[x.strip() for x in raw_dims.split(",") if x.strip()]

try:
    head=subprocess.check_output(["git","rev-parse","--short","HEAD"],
                                  cwd=d.get("cwd","."), stderr=subprocess.DEVNULL,
                                  text=True).strip()
except Exception:
    head="unknown"

hist_path=f"/tmp/fruity-audit-history-{session}.json"
if os.path.exists(hist_path):
    try:
        hist=json.loads(open(hist_path).read())
    except Exception:
        hist={"session":session,"ticks":[]}
else:
    hist={"session":session,"ticks":[]}

hist.setdefault("ticks",[]).append({
    "tick": len(hist["ticks"])+1,
    "ts": int(time.time()),
    "commit_head": head,
    "fail_dims": fail_dims,
    "verdict": verdict,
    "iter_reported": iter_n,
})
open(hist_path,"w").write(json.dumps(hist,ensure_ascii=False,indent=2))

if verdict in ("PASS","PASS_WITH_DEBT"):
    open(f"/tmp/fruity-audit-{session}.audited","w").write(verdict)
PY
exit 0
