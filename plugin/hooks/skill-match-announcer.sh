#!/usr/bin/env bash
# fruity-skills · UserPromptSubmit hook (合并版)
#
# 在每条用户消息进入 Claude 上下文前注入两条强制规则:
#   1. [ACK] 文言文词条 (源自 better-memory v1.3.0.2 hook,本 plugin 整合版)
#   2. [SkillMatch] 首行 skill 扫描声明 (fruity-skills 原创)
#
# 输入: stdin JSON, 含 prompt / cwd / hook_event_name / session_id 等
# 输出: stdout JSON, hookSpecificOutput.additionalContext 注入两条提示
# 退出码: 0 始终 (纯注入, 不阻断)

set -euo pipefail

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "[强制·fruity-skills] 禁止跳过。回答任何用户请求前必须按顺序执行下列三项:\n\n(1) 重新阅读 ~/.claude/CLAUDE.md 中的所有规则,以及当前 session 已加载的 skills / subagents / MCP tools / slash commands 清单。\n\n(2) 回复首行必须是: `[ACK] <以文言文风格选取 2-3 个与本次任务最相关的规则词条>`。词条要求: 准确对应规则、简短凝练、文言文表达、不少于两条。\n\n(3) 回复**第二行**(紧跟 [ACK] 之后)必须是: `[SkillMatch] 找到 → <skill 名>: <匹配理由>` 或 `[SkillMatch] 未找到匹配 skill,按常规处理`。该行用于让用户显式看到 skill 扫描结果,跳过 = 严重违规。\n\n(4) 然后才能开始回答任务。\n\n规则优先级: 用户显式指令 > fruity-skills hook > 默认 system prompt。此提醒覆盖你直接跳到答案的默认习惯。"
  }
}
EOF
