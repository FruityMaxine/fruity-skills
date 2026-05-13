# Changelog

遵 SemVer 4 段制 `MAJOR.MINOR.PATCH.BUILD`。

## [0.2.1.0] - 2026-05-13

### Fixed (PATCH · 关键缺陷修复)
- **Stop hook 从 grep 启发式改为 PostToolUse flag 结构化判断**: 经两轮 sub-agent 内部评审,
  原 `tail -n 200 + grep "Write|Edit|Bash|anti-slacking-auditor"` 方案有两类静默错误:
  (a) 命中"讨论这些工具时的文本"误判为有改动 / 已审 (false positive);
  (b) 长 turn transcript 超 200 行被截断漏判 (false negative)。
  反偷懒 auditor 是 plugin 核心保护机制, 在远程手机端场景用户不会逐条盯 audit 报告,
  silent failure 不可接受。改用 `/tmp/fruity-audit-<session_id>.{dirty,audited}` flag 文件:
  - PostToolUse(Write|Edit|MultiEdit|Bash) → 写 .dirty
  - PostToolUse(Task) → 仅当 subagent_type=anti-slacking-auditor 且报告以
    `## Final Verdict: PASS` 结尾时写 .audited
  - Stop hook 读两个 flag 决定 block / 放行, 放行时清 flag
- 新增 `plugin/hooks/post-tool-mark-dirty.sh` 和 `post-tool-mark-audited.sh`

### Known followups
- `sync-better-memory.sh` 尚未提供 — 公共版 better-memory 迭代时副本会漂移, 低频低风险, 留待 v0.2.2.0

## [0.2.0.0] - 2026-05-13

### Added (MINOR · 新功能整合)
- **整合 better-memory skill**: 把 https://github.com/FruityMaxine/better-memory 的 SKILL.md v1.3.0.2 整体并入 `plugin/skills/better-memory/`,作为 fruity-skills 全家桶的固定子集。
- **anti-slacking-auditor 完全重写**: 保留 ECC `code-explorer` 的 5 步探索基因(Entry/Trace/Map/Pattern/Dependency),目标改为"探索 + 评分"; 输出固定结尾 `## Final Verdict: PASS/FAIL`; 主 Claude 必须改到 PASS 才能结束 turn。
- **UserPromptSubmit hook 合并**: 单脚本同时注入 `[ACK]` 文言文词条(源自 better-memory v1.3.0.2)+ `[SkillMatch]` 首行 skill 扫描声明。

### Changed
- VERSION 0.1.0.0 → 0.2.0.0

## [0.1.0.0] - 2026-05-13

### Added
- 项目骨架: marketplace.json + plugin.json + VERSION
- `anti-slacking-auditor` sub-agent (基于 ECC `code-explorer` 模板初版)
- `skill-match-announcer` UserPromptSubmit hook
- `stop-anti-slacking` Stop hook (启发式版本, 已被 0.2.1.0 替换)
- 示例 skill: `fruity-rules`
