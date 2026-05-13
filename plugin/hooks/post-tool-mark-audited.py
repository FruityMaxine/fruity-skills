#!/usr/bin/env python3
"""fruity-skills PostToolUse(Task) hook impl. Reads JSON from stdin.

Behavior:
- subagent_type != anti-slacking-auditor -> exit 0 silently
- parse verdict (PASS/PASS_WITH_DEBT/BLOCKED/FAIL) + fail_dims
- append to /tmp/fruity-audit-history-<sid>.json
- PASS / PASS_WITH_DEBT -> write /tmp/fruity-audit-<sid>.audited
"""
import json
import sys
import os
import re
import subprocess
import time


def main() -> int:
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return 0
        d = json.loads(raw)
    except Exception:
        return 0

    session = d.get("session_id", "")
    if not session:
        return 0

    tinput = d.get("tool_input", {}) or {}
    if tinput.get("subagent_type", "") != "anti-slacking-auditor":
        return 0

    tresp = d.get("tool_response", "") or ""
    if isinstance(tresp, dict):
        parts = tresp.get("content", [])
        if isinstance(parts, list):
            text = "\n".join(
                [p.get("text", "") if isinstance(p, dict) else str(p) for p in parts]
            )
        else:
            text = str(parts)
    else:
        text = str(tresp)

    # v0.11.0.0: 新格式含 score, 例 "## Final Verdict: PASS [95/100 · iter 1/3]"
    # 兼容旧格式 "## Final Verdict: PASS [iter 1/3]"
    mv = re.search(
        r"##\s*Final Verdict:\s*(PASS_WITH_DEBT|PASS|WARN|BLOCKED|FAIL)"
        r"\s*\[(?:(\d+)/100\s*[·:]?\s*)?(?:iter\s*(\d+)/(?:3|\u221e|∞))?\]",
        text,
        re.IGNORECASE,
    )
    if not mv:
        # 旧格式 fallback (无 brackets)
        mv = re.search(
            r"##\s*Final Verdict:\s*(PASS_WITH_DEBT|PASS|WARN|BLOCKED|FAIL)",
            text,
            re.IGNORECASE,
        )
        if not mv:
            return 0
        verdict = mv.group(1).upper()
        score = -1
        iter_n = 1
    else:
        verdict = mv.group(1).upper()
        score = int(mv.group(2)) if mv.group(2) else -1
        iter_n = int(mv.group(3)) if mv.group(3) else 1

    # 单独的 Score 行 fallback
    if score < 0:
        ms = re.search(r"##\s*Score:\s*(\d+)/100", text)
        if ms:
            score = int(ms.group(1))

    mf = re.search(r"##\s*Fail Dimensions:\s*\[(.*?)\]", text)
    fail_dims = []
    if mf:
        raw_dims = mf.group(1).strip()
        if raw_dims:
            fail_dims = [x.strip() for x in raw_dims.split(",") if x.strip()]

    try:
        head = subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=d.get("cwd", "."),
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except Exception:
        head = "unknown"

    hist_path = f"/tmp/fruity-audit-history-{session}.json"
    try:
        if os.path.exists(hist_path):
            hist = json.loads(open(hist_path).read())
        else:
            hist = {"session": session, "ticks": []}
    except Exception:
        hist = {"session": session, "ticks": []}

    hist.setdefault("ticks", []).append({
        "tick": len(hist["ticks"]) + 1,
        "ts": int(time.time()),
        "commit_head": head,
        "fail_dims": fail_dims,
        "verdict": verdict,
        "iter_reported": iter_n,
        "score": score,
    })
    try:
        with open(hist_path, "w") as f:
            f.write(json.dumps(hist, ensure_ascii=False, indent=2))
    except Exception:
        pass

    if verdict in ("PASS", "PASS_WITH_DEBT"):
        try:
            with open(f"/tmp/fruity-audit-{session}.audited", "w") as f:
                f.write(verdict)
        except Exception:
            pass

    return 0


if __name__ == "__main__":
    sys.exit(main())
