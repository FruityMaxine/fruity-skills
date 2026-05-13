#!/usr/bin/env bash
# fruity-skills · UserPromptSubmit hook
# 强制 Claude 在回复首行用 [SkillMatch] 显式声明 skill 扫描结果
#
# 输入: stdin 是 JSON, 含 prompt / cwd / hook_event_name / session_id 等
# 输出: stdout JSON, hookSpecificOutput.additionalContext 注入提示
# 退出码: 0 始终 (纯注入, 不阻断)

set -euo pipefail

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "[强制·fruity-skills] 本次回复**首行**必须是: `[SkillMatch] 找到 → <skill 名>: <匹配理由>` 或 `[SkillMatch] 未找到匹配 skill,按常规处理`。\n\n规则:\n1. 在动手前(读文件 / 改文件 / 跑命令前)扫描当前 session 已加载的全部 skills / subagents / MCP tools / slash commands\n2. 把最匹配的那一个写在首行,带 1 句话匹配理由\n3. 没有匹配也要显式说明,不能省略\n4. 跳过首行声明 = 严重违规\n5. [ACK] 文言文词条放在 [SkillMatch] 之后另起一行(若全局规则触发)"
  }
}
EOF
