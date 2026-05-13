# Changelog

遵 SemVer 4 段制 `MAJOR.MINOR.PATCH.BUILD`。

## [0.2.0.0] - 2026-05-13

### Added (MINOR · 新功能整合)
- **整合 better-memory skill**: 把 https://github.com/FruityMaxine/better-memory 的 SKILL.md v1.3.0.2 整体并入 `plugin/skills/better-memory/`,作为 fruity-skills 全家桶的固定子集。better-memory 仍以独立公共仓存在,本副本仅用于个人跨设备一站式安装,不再单独维护。
- **anti-slacking-auditor 完全重写**: 保留 ECC `code-explorer` 的 5 步探索基因(Entry/Trace/Map/Pattern/Dependency),目标改为"探索 + 评分"; 输出固定结尾 `## Final Verdict: PASS/FAIL`; 主 Claude 必须改到 PASS 才能结束 turn (Stop hook 强制循环)。
- **UserPromptSubmit hook 合并**: 单脚本同时注入 `[ACK]` 文言文词条(源自 better-memory v1.3.0.2)+ `[SkillMatch]` 首行 skill 扫描声明。

### Changed
- VERSION 0.1.0.0 → 0.2.0.0 (新增 better-memory 整合 + auditor 重写,属功能性增强)

## [0.1.0.0] - 2026-05-13

### Added
- 项目骨架: marketplace.json + plugin.json + VERSION
- `anti-slacking-auditor` sub-agent (基于 ECC `code-explorer` 模板初版)
- `skill-match-announcer` UserPromptSubmit hook
- `stop-anti-slacking` Stop hook
- 示例 skill: `fruity-rules`
