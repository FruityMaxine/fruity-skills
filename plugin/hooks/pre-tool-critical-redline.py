#!/usr/bin/env python3
"""fruity-skills PreToolUse(Write|Edit|MultiEdit|Bash) red-line interceptor.

事前拦截 critical 红线, 不等 anti-slacking-auditor 事后审核:
  - Bash: git commit msg 含 Co-Auth trailer
  - Bash: git push --force/--no-verify to main/master
  - Bash: rm danger paths / mkfs / dd to physical disks
  - Write/Edit: write .env / private key / API key literals
  - Write/Edit: bind wildcard interface in listen/bind/host context
  - Write/Edit: systemd .service file with Chinese trailing comments

v2 (2026-05-22): 新增"对话上下文授权"机制.
  - 每条 critical 规则归入一个 category.
  - 检测 transcript_path 中最近 8 条用户消息, 若含通用授权词或
    类别相关授权词 -> 放行 (打 stderr 痕迹), 不二次拦截.
  - _no_bypass 类别 (rm 危险 / Co-Auth / secrets / bind wildcard) 永不放行.
  - hook 自身脚本路径白名单 (避免规则文档字面被自己误命中).
"""
import json
import os
import re
import sys
from pathlib import Path

# ---------- 白名单: hook 自身路径 + 备份, 跳过内容扫描 ----------
SELF_PATH_SUBSTR = "fruity-skills/plugin/hooks/pre-tool-critical-redline"

# ---------- 通用授权词 (任何可绕类别均沉默放行) ----------
# 注: hook v3 起非 _no_bypass 类已转软提醒, 词典作用从"绕过 block"
#     降级为"沉默模式" (连 stderr 警告都不打).
GENERIC_AUTH = [
    # 英文常用确认词
    r"\b(go|yes|confirm|proceed|do it|sure|ok|okay)\b",
    r"\b(go\s+ahead|make it so|let'?s\s+(go|do it|ship))\b",
    r"\b(approved?|granted|sounds good|fine|great)\b",
    # 中文常用确认 / 推进语
    r"(确认|授权|继续做|没问题|放心|可以执行|动手|拍板|这就|那就)",
    r"(干|搞|没事|行|好的?|嗯|是的|对的?|执行|开干)",
    r"(同意|批准|授权|允许|让你做|继续|往下走)",
    # 形如 emoji 同意
    r"(👍|🆗|✅)",
]

# ---------- 按 category 的专项授权词 ----------
CATEGORY_AUTH = {
    "release": [
        r"(?:^|[\s,，])(发|发布|发版|发个release|发布release)(?:[\s$！!。.,，]|$)",
        r"\brelease\b",
        r"\bship\b",
        r"上线",
        r"先发布",
        r"发个 ?release",
        r"创建 ?release",
        r"打 ?release",
        r"做(一个|个)? ?release",
    ],
    "publish_pkg": [
        r"\bpublish\b",
        r"推到 ?(npm|pypi|crates|registry|hub)",
        r"发布到 ?(npm|pypi|crates)",
    ],
    "push_force": [
        r"强 ?推",
        r"--force",
        r"\bforce[\s-]?push\b",
        r"硬推",
    ],
    "docker_push": [
        r"docker push",
        r"推 ?(镜像|image)",
        r"\bghcr\b",
        r"推到 ?(ghcr|registry|docker hub)",
    ],
    "system_action": [
        r"\b(reboot|shutdown)\b",
        r"重启(系统|服务器|这台)",
        r"关机",
    ],
    "firewall": [
        r"(清|重置|禁用) ?(防火墙|ufw|iptables)",
        r"开 ?(防火墙|ufw|iptables)",
        r"\b(ufw|iptables)\b.*?(disable|reset|flush)",
    ],
    "git_config": [r"改 ?git ?config", r"改 ?身份"],
    "git_remote": [r"改 ?remote", r"换 ?remote", r"指 ?到 ?(新|别的) ?仓"],
    "supply_chain": [r"\bcurl\s*\|\s*bash\b", r"放行 ?(curl|wget) ?\|? ?bash"],
    "history_wipe": [r"清 ?history", r"擦 ?痕迹"],
}


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


def _extract_text_from_content(content) -> list[str]:
    out: list[str] = []
    if isinstance(content, str):
        out.append(content)
    elif isinstance(content, list):
        for blk in content:
            if isinstance(blk, dict):
                if blk.get("type") == "text":
                    out.append(blk.get("text", "") or "")
                elif "text" in blk:
                    out.append(blk.get("text", "") or "")
            elif isinstance(blk, str):
                out.append(blk)
    return out


def transcript_recent_user_text(transcript_path: str, n: int = 8) -> str:
    if not transcript_path:
        return ""
    try:
        p = Path(transcript_path)
        if not p.exists():
            return ""
        lines = p.read_text(encoding="utf-8", errors="ignore").splitlines()
    except Exception:
        return ""

    user_msgs: list[str] = []
    for line in reversed(lines):
        if not line.strip():
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        role = (
            obj.get("role")
            or obj.get("type")
            or (obj.get("message") or {}).get("role")
        )
        if role != "user":
            continue
        content = (
            obj.get("content")
            or (obj.get("message") or {}).get("content")
            or ""
        )
        texts = _extract_text_from_content(content)
        for t in texts:
            if "<system-reminder>" in t and len(t) < 200:
                continue
            user_msgs.append(t)
        if len(user_msgs) >= n:
            break
    return "\n".join(user_msgs)


def is_authorized(transcript_path: str, category: str) -> bool:
    blob = transcript_recent_user_text(transcript_path, n=8)
    if not blob:
        return False
    patterns = list(GENERIC_AUTH) + list(CATEGORY_AUTH.get(category, []))
    for p in patterns:
        if re.search(p, blob, re.IGNORECASE):
            return True
    return False


def check_bash(cmd: str) -> tuple[str, str]:
    if not cmd:
        return "", ""

    if re.search(r"git\s+commit", cmd) and re.search(r"Co-Authored-By", cmd, re.IGNORECASE):
        return (
            "git commit 消息含 Co-Authored-By trailer. FruityMaxine 全局规则: "
            "所有 commit author/contributor 永远只有用户本人, 不允许 AI co-author. "
            "去掉 trailer 后重新 commit.",
            "_no_bypass",
        )

    if re.search(r"git\s+push\s+.*(--force|--no-verify|\s+-f\b)", cmd):
        if re.search(r"\s(main|master)\b", cmd) or "origin" in cmd:
            return (
                "git push --force/--no-verify 到 main/master 是高风险操作. "
                "明确告知用户并征得确认后才允许.",
                "push_force",
            )

    # rm 危险: 仅在 cmd 真的以 rm 开头 / 含独立 rm token 时检测
    rm_match = re.search(r"(?:^|[\s;&|`])rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-rf|-fr)\s+(/|/\*|~/?$|\.\s*$)", cmd)
    if rm_match:
        return f"危险 rm 命令: {cmd[:80]}. 会大规模删除系统根/家目录.", "_no_bypass"

    if re.search(r"(?:^|[\s;&|])\b(mkfs|fdisk|wipefs)\b.*?/dev/", cmd):
        return f"磁盘格式化命令: {cmd[:80]}. 会摧毁设备数据.", "_no_bypass"
    if re.search(r"(?:^|[\s;&|])dd\s+.*of=/dev/sd", cmd):
        return f"dd to /dev/sd*: {cmd[:80]}. 会直写物理盘.", "_no_bypass"

    if re.search(r"curl\s+[^|]*\|\s*(sudo\s+)?bash", cmd) or \
       re.search(r"wget\s+[^|]*\|\s*(sudo\s+)?bash", cmd):
        return (
            f"curl|bash / wget|bash 模式: {cmd[:100]}. "
            "未经签名校验直接执行远程脚本是高风险供应链注入向量. "
            "下载到本地审查后再执行.",
            "supply_chain",
        )

    if re.search(r"\bufw\s+(disable|--force\s+reset|reset)\b", cmd):
        return (
            f"ufw disable/reset: {cmd[:80]}. "
            "会清空防火墙规则, 暴露所有内部端口到公网. 明确告知用户并征得确认.",
            "firewall",
        )

    if re.search(r"\biptables\s+(-F\b|--flush)", cmd):
        return (
            f"iptables -F (flush): {cmd[:80]}. 会清空所有防火墙规则。明确告知用户并征得确认.",
            "firewall",
        )

    if re.search(r"\bchmod\s+(-R\s+)?(777|0?777)\s+(/|/etc|/var|/usr|/opt)\b", cmd):
        return (
            f"chmod 777 系统目录: {cmd[:80]}. 会移除所有权限保护. 改用最小必要权限.",
            "_no_bypass",
        )

    if re.search(r":\(\)\s*\{[^}]*:[\s|]*:[^}]*\}\s*;\s*:", cmd):
        return f"fork bomb 模式: {cmd[:60]}. 会耗尽系统进程表.", "_no_bypass"

    if re.search(r"shutdown\s+(now|-h)|reboot\s*(now)?$|init\s+[06]\b", cmd):
        return (
            f"系统重启/关机命令: {cmd[:60]}. 会中断所有服务. "
            "用户明确请求时手动跑, hook 拦默认行为.",
            "system_action",
        )

    if re.search(r"history\s+-c\b|>\s*~?/.bash_history\b", cmd):
        return (
            f"清 shell history: {cmd[:60]}. 看似掩盖痕迹, 不允许默认行为.",
            "history_wipe",
        )

    if re.search(r"git\s+config\s+(--global\s+)?user\.(name|email)\s+", cmd):
        if not re.search(r"(FruityMaxine|donaldholmestte@gmail\.com)", cmd, re.IGNORECASE):
            return (
                f"git config user.name/email 改成非 FruityMaxine 身份: {cmd[:100]}. "
                "用户独占 git author/contributor, 不允许 AI / 别人邮箱替换。",
                "_no_bypass",
            )

    if re.search(r"git\s+remote\s+(set-url|add)\s+origin\s+", cmd):
        if not re.search(r"(github\.com[:/]FruityMaxine/|x-access-token:)", cmd):
            return (
                f"git remote 改到非 FruityMaxine 仓: {cmd[:100]}. "
                "防止误推到他人仓。明确说明授权后才允许。",
                "git_remote",
            )

    if re.search(r"\b(npm|yarn|pnpm)\s+publish\b", cmd):
        return (
            f"npm/yarn publish: {cmd[:80]}. 对个人项目通常不需要发布到公网 registry。",
            "publish_pkg",
        )
    if re.search(r"\bpip\s+upload\b|twine\s+upload\b", cmd):
        return (f"pip/twine upload: {cmd[:80]}. 发布 Python 包到 PyPI。", "publish_pkg")
    if re.search(r"\bcargo\s+publish\b", cmd):
        return (f"cargo publish: {cmd[:80]}. 发布 Rust crate。", "publish_pkg")
    if re.search(r"\bdocker\s+push\b", cmd):
        return (f"docker push: {cmd[:80]}. 推送镜像到 registry。", "docker_push")

    if re.search(r"\bgh\s+release\s+(create|edit|delete)\b", cmd):
        return (f"gh release {cmd[:80]}. 公开发布版本。", "release")

    return "", ""


# 字符串拼接, 避免 hook 误扫自己规则文档时命中
_BIND_WILDCARD_PATTERN = (
    r"(?:listen|bind|host)[\s\"'=:]+"
    + r"0" + r"\." + r"0" + r"\." + r"0" + r"\." + r"0"
)


def check_write_content(file_path: str, content: str) -> tuple[str, str]:
    if not content:
        return "", ""

    # 白名单: 跳过 hook 自身脚本 + 备份
    if SELF_PATH_SUBSTR in (file_path or ""):
        return "", ""

    # bind 通配地址 (4 个零, 点分隔)
    for m in re.finditer(_BIND_WILDCARD_PATTERN, content, re.IGNORECASE):
        snippet = content[max(0, m.start() - 20):m.end() + 20]
        return (
            f"文件 {file_path} 含 bind wildcard address (位置: {snippet!r}). "
            "FruityMaxine 规则: 后端服务必须 bind 127.0.0.1, 由 Caddy 反代.",
            "_no_bypass",
        )

    secret_patterns = [
        (r"AKIA[0-9A-Z]{16}", "AWS access key ID"),
        (r"ghp_[A-Za-z0-9]{36,}", "GitHub Personal Access Token"),
        (r"gho_[A-Za-z0-9]{36,}", "GitHub OAuth token"),
        (r"sk-[A-Za-z0-9]{20,}", "OpenAI/Anthropic SK key"),
        (r"-----BEGIN\s+(RSA\s+|EC\s+|OPENSSH\s+|DSA\s+)?PRIVATE\s+KEY-----", "PEM private key"),
        (r"(?:mongodb|postgres(?:ql)?|mysql|redis|amqp)://[^:\s]+:[^@\s]+@[^\s/]+",
         "DB connection string with embedded password"),
        (r"xox[bp]-[0-9]+-[0-9]+-[0-9]+-[a-zA-Z0-9]+", "Slack bot/user token"),
        (r"AIza[0-9A-Za-z_-]{35}", "Google API key"),
        (r"\b(?:DOCKER_AUTH|JWT_SECRET|SESSION_SECRET|FLASK_SECRET|DJANGO_SECRET_KEY)\s*=\s*['\"][^'\"]{16,}['\"]",
         "Hardcoded secret env literal"),
    ]
    for pat, name in secret_patterns:
        if re.search(pat, content):
            return (
                f"文件 {file_path} 含疑似 {name} 字面值. "
                "secrets 必须用 env / vault, 不入 git 历史.",
                "_no_bypass",
            )

    if file_path.endswith(".service"):
        for ln_no, line in enumerate(content.splitlines(), 1):
            if not line.lstrip().startswith("#") and "#" in line:
                after = line.split("#", 1)[1]
                if re.search(r"[\u4e00-\u9fff]", after):
                    return (
                        f"systemd unit {file_path} 第 {ln_no} 行有行尾中文注释: {line[:80]!r}. "
                        "systemd 不支持行尾注释, 整行被静默忽略, 资源限制失效. 注释独立成行.",
                        "_no_bypass",
                    )

    if re.search(r"(^|/)\.env(\.|$)", file_path):
        return (
            f"写入 {file_path} 看起来是 .env 文件. "
            "确认 .gitignore 已忽略且真值不入 commit.",
            "_no_bypass",
        )

    return "", ""


def main() -> int:
    d = get_input()
    if not d:
        return 0

    transcript_path = d.get("transcript_path", "") or ""
    tool_name = d.get("tool_name", "")
    tinput = d.get("tool_input", {}) or {}

    def maybe_block(reason: str, category: str) -> int:
        """三档:
          _no_bypass  → 硬拦 (rm 危险 / Co-Auth / secrets / bind 通配 / systemd 等)
          已授权     → 沉默放行 (连 stderr 都不打)
          未授权     → 软提醒 (stderr 警告, 工具继续执行, 不 block)
        """
        if category == "_no_bypass":
            return block(reason)
        if is_authorized(transcript_path, category):
            return 0  # 沉默
        # 软提醒 — 不 block
        sys.stderr.write(
            f"[fruity-skills 软提醒 · {category}] {reason}\n"
            f"  (此为提醒非拦截, 命令将继续执行. 如需硬拦改 hook 把 '{category}' "
            f"归入 _no_bypass.)\n"
        )
        return 0

    if tool_name == "Bash":
        cmd = tinput.get("command", "")
        reason, category = check_bash(cmd)
        if reason:
            return maybe_block(reason, category)

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
            reason, category = check_write_content(fp, c)
            if reason:
                return maybe_block(reason, category)

    return 0


if __name__ == "__main__":
    sys.exit(main())
