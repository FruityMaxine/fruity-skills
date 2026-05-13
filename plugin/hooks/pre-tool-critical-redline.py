#!/usr/bin/env python3
"""fruity-skills PreToolUse(Write|Edit|MultiEdit|Bash) red-line interceptor.

事前拦截 critical 红线, 不等 anti-slacking-auditor 事后审核:
  - Bash: git commit msg 含 Co-Authored-By
  - Bash: git push --force/--no-verify to main/master
  - Bash: rm -rf 危险路径 / mkfs / dd to /dev/sd*
  - Write/Edit: 写 .env / private key / API key
  - Write/Edit: bind 0.0.0.0 在 listen/bind/host 语境
  - Write/Edit: systemd .service 文件含行尾中文注释

命中 -> 输出 decision=block JSON, exit 0. 未命中 -> exit 0 silent.
"""
import json
import sys
import re


def get_input() -> dict:
    try:
        raw = sys.stdin.read()
        return json.loads(raw) if raw.strip() else {}
    except Exception:
        return {}


def block(reason: str) -> int:
    out = {"decision": "block", "reason": f"[fruity-skills CRITICAL 红线拦截] {reason}"}
    print(json.dumps(out, ensure_ascii=False))
    return 0


def check_bash(cmd: str) -> str:
    if not cmd:
        return ""

    if re.search(r"git\s+commit", cmd) and re.search(r"Co-Authored-By", cmd, re.IGNORECASE):
        return ("git commit 消息含 Co-Authored-By trailer. FruityMaxine 全局规则: "
                "所有 commit author/contributor 永远只有用户本人, 不允许 AI co-author. "
                "去掉 trailer 后重新 commit.")

    if re.search(r"git\s+push\s+.*(--force|--no-verify|\s+-f\b)", cmd):
        if re.search(r"\s(main|master)\b", cmd) or "origin" in cmd:
            return ("git push --force/--no-verify 到 main/master 是高风险操作. "
                    "明确告知用户并征得确认后才允许.")

    if re.search(r"rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-rf|-fr)\s+(/|/\*|~/?$|\.\s*$)", cmd):
        return f"危险 rm 命令: {cmd[:80]}. 会大规模删除系统根/家目录."

    if re.search(r"\b(mkfs|fdisk|wipefs)\b.*/dev/", cmd):
        return f"磁盘格式化命令: {cmd[:80]}. 会摧毁设备数据."
    if re.search(r"dd\s+.*of=/dev/sd", cmd):
        return f"dd to /dev/sd*: {cmd[:80]}. 会直写物理盘."

    return ""


def check_write_content(file_path: str, content: str) -> str:
    if not content:
        return ""

    for m in re.finditer(r"(?:listen|bind|host)[\s\"'=:]+0\.0\.0\.0", content, re.IGNORECASE):
        snippet = content[max(0, m.start() - 20):m.end() + 20]
        return (f"文件 {file_path} 含 bind 0.0.0.0 (位置: {snippet!r}). "
                "FruityMaxine 规则: 后端服务必须 bind 127.0.0.1, 由 Caddy 反代.")

    secret_patterns = [
        (r"AKIA[0-9A-Z]{16}", "AWS access key ID"),
        (r"ghp_[A-Za-z0-9]{36,}", "GitHub Personal Access Token"),
        (r"gho_[A-Za-z0-9]{36,}", "GitHub OAuth token"),
        (r"sk-[A-Za-z0-9]{20,}", "OpenAI/Anthropic SK key"),
        (r"-----BEGIN\s+(RSA\s+|EC\s+|OPENSSH\s+|DSA\s+)?PRIVATE\s+KEY-----", "PEM private key"),
    ]
    for pat, name in secret_patterns:
        if re.search(pat, content):
            return (f"文件 {file_path} 含疑似 {name} 字面值. "
                    "secrets 必须用 env / vault, 不入 git 历史.")

    if file_path.endswith(".service"):
        for ln_no, line in enumerate(content.splitlines(), 1):
            if not line.lstrip().startswith("#") and "#" in line:
                after = line.split("#", 1)[1]
                if re.search(r"[\u4e00-\u9fff]", after):
                    return (f"systemd unit {file_path} 第 {ln_no} 行有行尾中文注释: {line[:80]!r}. "
                            "systemd 不支持行尾注释, 整行被静默忽略, 资源限制失效. 注释独立成行.")

    if re.search(r"(^|/)\.env(\.|$)", file_path):
        return (f"写入 {file_path} 看起来是 .env 文件. "
                "确认 .gitignore 已忽略且真值不入 commit.")

    return ""


def main() -> int:
    d = get_input()
    if not d:
        return 0

    tool_name = d.get("tool_name", "")
    tinput = d.get("tool_input", {}) or {}

    if tool_name == "Bash":
        cmd = tinput.get("command", "")
        reason = check_bash(cmd)
        if reason:
            return block(reason)

    elif tool_name in ("Write", "Edit", "MultiEdit"):
        fp = tinput.get("file_path", "")
        contents = []
        if "content" in tinput:
            contents.append(tinput["content"])
        if "new_string" in tinput:
            contents.append(tinput["new_string"])
        edits = tinput.get("edits", [])
        if isinstance(edits, list):
            for e in edits:
                if isinstance(e, dict) and "new_string" in e:
                    contents.append(e["new_string"])

        for c in contents:
            if not isinstance(c, str):
                continue
            reason = check_write_content(fp, c)
            if reason:
                return block(reason)

    return 0


if __name__ == "__main__":
    sys.exit(main())
