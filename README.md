# fruity-skills

FruityMaxine 的私人 Claude Code 规则集，跨设备迁移时随身携带。

**当前版本**: v0.1.0.0
**作者**: FruityMaxine (donaldholmestte@gmail.com)

## 它是什么

一个可以 `add` 到 Claude Code 的 marketplace plugin。装上之后，给当前机器的 Claude 加两条永久规则：

### 1. Skill 显式匹配声明（hook）

**问题**：全局 CLAUDE.md 写了"工具发现规则"，让 Claude 收到 prompt 后扫描所有 skill 看有没有匹配。但这个扫描是心里默念，用户看不到 Claude 到底扫没扫。

**这个 plugin 怎么做**：通过 `UserPromptSubmit` hook 注入强制提醒，让 Claude 在每条回复的**开头第一句**显式输出 skill 匹配结果，格式固定：

```
[SkillMatch] 找到 → <skill 名>: <为什么匹配>
            或：未找到匹配 skill，按常规处理
```

跳过 = 严重违规，用户一眼识别。

### 2. 反偷懒 sub-agent 审核（hook + sub-agent）

**问题**：全局 CLAUDE.md 写了"反偷懒规则"，但 Claude 经常自己声明"已完成"就 Stop，实际可能偷工减料、漏需求、留 stub。

**这个 plugin 怎么做**：
- 提供 `anti-slacking-auditor` sub-agent（基于 ECC `code-explorer` 模板改造）
- 通过 `Stop` hook 拦截 Claude 的 turn 结束，强制调用 sub-agent 审核：
  - 用户原话 vs 实际改动差距
  - 是否有 stub / TODO / "范本待补"
  - 是否漏掉用户列出的需求项
  - UI 改动是否实测
- 审核通过才放行 Stop；不过 → 退回 Claude 继续干

## 安装

```bash
# 临时本地
claude plugin marketplace add /path/to/fruity-skills
claude plugin install fruity-skills@fruity-skills

# 跨设备（push 到 GitHub 私库后）
claude plugin marketplace add https://github.com/<user>/fruity-skills.git
claude plugin install fruity-skills@fruity-skills
```

## 文件结构

```
fruity-skills/
├── .claude-plugin/marketplace.json   # marketplace manifest
├── plugin/                            # plugin 主体
│   ├── .claude-plugin/plugin.json
│   ├── hooks/{hooks.json,*.sh}        # UserPromptSubmit + Stop
│   ├── agents/anti-slacking-auditor.md
│   ├── skills/fruity-rules/SKILL.md
│   └── scripts/
├── VERSION                            # 4 段 SemVer
├── README.md / CLAUDE.md / CHANGELOG.md
```

## 版本规则

遵 FruityMaxine 全局规则：每次任何修改必须同步升 `VERSION`，4 段制 `MAJOR.MINOR.PATCH.BUILD`，右侧归零。

## License

MIT
