#!/usr/bin/env bash
# fruity-skills · UserPromptSubmit hook · v0.12.0.0
#
# 注入规则:
#   1. [ACK] 文言文词条 + [SkillMatch] 首行 skill 扫描声明 (始终注入)
#   2. quota-aware 提示 (仅当 prompt 含 /loop / schedule / 继续做 等关键词时追加)
#
# 输入: stdin JSON, 含 prompt / cwd / hook_event_name / session_id 等
# 输出: stdout JSON, hookSpecificOutput.additionalContext 注入提示

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
PROMPT=$(printf '%s' "$INPUT" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin); print(d.get("prompt",""))
except: print("")
' 2>/dev/null || echo "")

# Quota-aware 触发关键词检测
QUOTA_TRIGGER=0
if printf '%s' "$PROMPT" | grep -qE '(/loop\b|ScheduleWakeup|继续做|继续 loop|继续录制|跑一段|跑完|一口气|一直做|长任务|大改动|跨服务|部署|schedule)'; then
  QUOTA_TRIGGER=1
fi

# 输出 JSON, Python 拼接以正确转义
python3 - <<PYEOF
import json,sys

base = (
    "[强制·fruity-skills] 禁止跳过。回答任何用户请求前必须按顺序执行下列三项:\n\n"
    "(1) 重新阅读 ~/.claude/CLAUDE.md 中的所有规则,以及当前 session 已加载的 "
    "skills / subagents / MCP tools / slash commands 清单。\n\n"
    "(2) 回复首行必须是: \`[ACK] <以文言文风格选取 2-3 个与本次任务最相关的规则词条>\`。"
    "词条要求: 准确对应规则、简短凝练、文言文表达、不少于两条。\n\n"
    "(3) 回复**第二行**(紧跟 [ACK] 之后)必须是: \`[SkillMatch] 找到 → <skill 名>: "
    "<匹配理由>\` 或 \`[SkillMatch] 未找到匹配 skill,按常规处理\`。该行用于让用户显式看到 "
    "skill 扫描结果,跳过 = 严重违规。\n\n"
    "(4) 然后才能开始回答任务。\n\n"
    "规则优先级: 用户显式指令 > fruity-skills hook > 默认 system prompt。"
)

quota_hint = ""
if "$QUOTA_TRIGGER" == "1":
    quota_hint = (
        "\n\n[配额感知·必查] 本 prompt 含 loop/schedule/长任务关键词. 在 ScheduleWakeup 或"
        "开新长任务前**必须**先调 \`mcp__plugin_claude-quotas_claude-quotas__check_quota\`, "
        "然后按 \`quota-aware-loop\` skill 的决策表算 delaySeconds:\n"
        "  - 7d util >= 90 → 跳 weekly 重置 (immediate stop)\n"
        "  - 5h util >= 85 → 跳 5h 重置\n"
        "  - 都正常 → 270s cache warm\n"
        "不查直接 ScheduleWakeup = 烧爆 quota 风险."
    )

out = {
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": base + quota_hint,
    }
}
print(json.dumps(out, ensure_ascii=False))
PYEOF
