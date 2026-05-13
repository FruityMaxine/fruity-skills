# fruity-skills

[![test](https://github.com/FruityMaxine/fruity-skills/actions/workflows/test.yml/badge.svg)](https://github.com/FruityMaxine/fruity-skills/actions/workflows/test.yml)
[![version](https://img.shields.io/badge/version-0.6.0.0-blue)](https://github.com/FruityMaxine/fruity-skills/releases)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![tests](https://img.shields.io/badge/tests-32%20pass-brightgreen)](plugin/tests/run-tests.sh)

FruityMaxine 的私人 Claude Code skill 全家桶,跨设备迁移时一站式安装。

**当前版本**: v0.6.0.0
**作者**: FruityMaxine (donaldholmestte@gmail.com)

## 它是什么

一个可 `add` 到 Claude Code 的 marketplace plugin。装上后给当前机器的 Claude 加三层能力:

### 1. Skill 显式匹配 + 文言文 ACK (UserPromptSubmit hook)

通过 `UserPromptSubmit` hook 强制每条回复**前两行**:

```
[ACK] <2-3 个文言文规则词条>
[SkillMatch] 找到 → <skill 名>: <匹配理由>   (或 未找到匹配 skill,按常规处理)
```

跳过 = 严重违规。让用户一眼看到 Claude 有没有扫 skill / 有没有读规则。

### 2. 反偷懒探索式审核 (Stop hook + anti-slacking-auditor sub-agent)

`anti-slacking-auditor` 是基于 ECC `code-explorer` 改造的 sub-agent —— **保留 5 步深度探索基因**(Entry / Trace / Map / Pattern / Dependency),目标改为"探索 + 评分":

1. **Intent Decoding**: 拆解用户原话原子需求
2. **Claim-vs-Reality Trace**: git diff / Read 验证主 Claude 的承诺
3. **Coverage Map**: 原子需求逐项核对
4. **Slacking Pattern Recognition**: Grep `TODO/stub/范本/接力/后续可补/占位`
5. **Compliance Audit**: VERSION 升号、Co-Authored-By 检查、UI 实测、UFW、token Cookie 守门、INDEX.md 同步等

输出固定结尾 `## Final Verdict: PASS` 或 `## Final Verdict: FAIL`。**FAIL → 主 Claude 必须按清单改,再次派来复审,直到 PASS,才能结束 turn**。Stop hook 拦在这里,跳过不允许。

### 3. better-memory 跨会话记忆系统 (skill)

把 https://github.com/FruityMaxine/better-memory v1.3.0.2 整体整合进来作为内置 skill。功能不变:

- 4 个去向: `CLAUDE.md` / `memory/about_me/` / `memory/reference/` / `memory/rules/`
- 分类决策树: rule vs fact、always-on vs conditional、personal vs technical
- INDEX.md 自动同步
- intent-based 触发 (而非关键词匹配)

`better-memory` 公共仓继续独立维护;本 plugin 内仅作个人版本固化副本。

## 安装

```bash
# 本机
claude plugin marketplace add /srv/agent-workspace/projects/2026-05-13-fruity-skills
claude plugin install fruity-skills@fruity-skills

# 跨设备 (push 到私库后)
claude plugin marketplace add https://github.com/FruityMaxine/fruity-skills.git
claude plugin install fruity-skills@fruity-skills
```

## 文件结构

```
fruity-skills/
├── .claude-plugin/marketplace.json    # marketplace manifest
├── plugin/                             # plugin 主体
│   ├── .claude-plugin/plugin.json
│   ├── hooks/
│   │   ├── hooks.json
│   │   ├── skill-match-announcer.sh   # [ACK] + [SkillMatch] 合并版
│   │   └── stop-anti-slacking.sh      # Stop 拦截 + 触发审核
│   ├── agents/
│   │   └── anti-slacking-auditor.md   # 探索式审核 sub-agent
│   ├── skills/
│   │   ├── fruity-rules/SKILL.md      # 跨设备红线速查
│   │   └── better-memory/SKILL.md     # better-memory v1.3.0.2 整合副本
│   └── scripts/
├── VERSION                             # 4 段 SemVer SSOT
├── README.md / CLAUDE.md / CHANGELOG.md
```

## 与公共 better-memory 的关系

| | 公共版 better-memory | 本 fruity-skills 内副本 |
|---|---|---|
| 仓库 | github.com/FruityMaxine/better-memory | 内置在 plugin/skills/better-memory/ |
| 受众 | 任何人 | 仅 FruityMaxine 个人 |
| 更新 | 公共版迭代 | 跟随公共版同步,不单独修改 |
| 单独安装 | 可以独立装 | 不可独立装,随 fruity-skills 一起 |

**别人不会装 fruity-skills。它专门为 FruityMaxine 个人定制,把他常用的所有 skill 打包到一个 plugin 里,跨设备一条命令装全。**

## 版本规则

遵 FruityMaxine 全局规则: 每次任何修改必须同步升 `VERSION`,4 段 `MAJOR.MINOR.PATCH.BUILD`,右侧归零。

## License

MIT
