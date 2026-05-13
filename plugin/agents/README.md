# fruity-skills sub-agents

四个独立 sub-agent 形成 FruityMaxine 的 commit 工作流闭环。每个 agent 职责单一，相互配合而不重叠。

## 四件套

```
┌────────────────────────┐
│   主 Claude 改完代码   │
└───────────┬────────────┘
            ↓
   ┌────────────────────┐         "现在改了 N 个文件,
   │  version-bumper    │  ←──┐    当前 VERSION=x.y.z.w,
   │  决策 SemVer 段     │     │    升哪段?"
   └────────┬───────────┘     │
            ↓ "MINOR → 0.x+1.0.0"
   ┌────────────────────┐
   │  主 Claude 写 VERSION/manifest    │
   └────────┬───────────┘
            ↓
   ┌────────────────────┐         "新版 0.x.0.0 包含 ...,
   │  changelog-writer  │  ←──┐    生成 CHANGELOG 段"
   │  写 CHANGELOG 段    │     │
   └────────┬───────────┘     │
            ↓ "## [0.x.0.0] - YYYY-MM-DD ..."
   ┌────────────────────┐
   │  主 Claude Edit CHANGELOG.md     │
   └────────┬───────────┘
            ↓
   ┌────────────────────┐         "改了 ..., bump=MINOR,
   │  commit-msg-writer │  ←──┐    生成 commit msg"
   │  写 commit message │     │
   └────────┬───────────┘     │
            ↓ "feat(scope): v0.x.0.0 ..."
   ┌────────────────────┐
   │  主 Claude git commit -m "..."   │
   └────────┬───────────┘
            ↓ (PostToolUse → .dirty flag)
   ┌────────────────────┐
   │  主 Claude 试图 Stop turn        │
   └────────┬───────────┘
            ↓ (Stop hook 拦)
   ┌──────────────────────┐
   │  anti-slacking-auditor   │  ← Step 0 读 history, 1 git diff,
   │  全维度审 + 评分         │     2-5 评分 + Final Verdict
   └────────┬─────────────┘
            ↓ PASS/PASS_WITH_DEBT → 写 .audited flag
   ┌────────────────────┐
   │  Stop hook 放行     │
   │  turn 结束         │
   └────────────────────┘
```

## 四件套职责矩阵

| Sub-agent | 职责 | 输出 | 何时触发 |
|---|---|---|---|
| **anti-slacking-auditor** | 审核已完成的工作是否偷懒 / 漏需求 / 违规 | PASS / PASS_WITH_DEBT / BLOCKED / FAIL + 12 维度评分 + 整改清单 | Stop hook 强制 (主 Claude 不能跳过) |
| **version-bumper** | 决策 SemVer 升哪段 + 计算新版本号 | `MAJOR\|MINOR\|PATCH\|BUILD` + 新版本号 + 右侧归零判断 + reasoning | 主 Claude 手动派 (commit 前) |
| **changelog-writer** | 生成 Keep-a-Changelog 段落 markdown | 完整段落文本 (含 `## [version] - date` + sections) | 主 Claude 手动派 (写 VERSION 后) |
| **commit-msg-writer** | 生成 Conventional Commits 格式 commit msg | one-liner + multi-line + reasoning, **无 Co-Authored-By** | 主 Claude 手动派 (Edit CHANGELOG 后) |

## 红线 (横跨所有四件套)

| 红线 | 哪个 agent / hook 守 |
|---|---|
| Co-Authored-By trailer | PreToolUse 红线 hook + commit-msg-writer 拒绝输出 + anti-slacking-auditor critical FAIL |
| bind 0.0.0.0 | PreToolUse 红线 + anti-slacking-auditor critical FAIL |
| Secrets 入 git (PEM/AWS/GitHub/Slack/Google/DB 连接串/硬编码 env) | PreToolUse 红线 |
| systemd 行尾中文注释 | PreToolUse 红线 + anti-slacking-auditor critical FAIL |
| 非中文回复 | anti-slacking-auditor critical FAIL |
| VERSION 未升 | anti-slacking-auditor major FAIL |
| 偷懒话术 (TODO/stub/范本) | anti-slacking-auditor pattern recognition |
| `git config` 改非 FruityMaxine 邮箱 | PreToolUse 红线 |
| `git remote` 改到非 FruityMaxine 仓 | PreToolUse 红线 |
| 发布命令 (npm/cargo/twine publish, gh release) | PreToolUse 红线 |

## 主 Claude 标准 commit 流程模板

```text
1. git add -A
2. Task(subagent_type="version-bumper", prompt="改了 X/Y/Z, 当前 VERSION=A.B.C.D, 升哪段?")
   → 拿到 segment + new_version
3. echo "<new_version>" > VERSION
   编辑 marketplace.json / plugin.json version 字段
4. Task(subagent_type="changelog-writer", prompt="VERSION 从 A.B.C.D 升到 <new>, segment=<seg>, 改了 ...")
   → 拿到 CHANGELOG 段
5. Edit CHANGELOG.md 顶部插入新段
6. Task(subagent_type="commit-msg-writer", prompt="VERSION <new>, segment=<seg>, 改了 ...")
   → 拿到 commit msg
7. git commit -m "<one-liner>"
8. (尝试 Stop turn) → PostToolUse 写 .dirty flag → Stop hook 拦
9. Task(subagent_type="anti-slacking-auditor", prompt="用户原话 ..., 我做了 ..., git diff --stat: ...")
   → PASS / PASS_WITH_DEBT 写 .audited → Stop 放行
   → 若 BLOCKED / FAIL → 修后再派, 直到 PASS
10. 可选 git push
```

## 第 5 个: pr-creator (v0.9.0.0)

| Sub-agent | 职责 | 输出 | 何时触发 |
|---|---|---|---|
| **pr-creator** | 生成 PR title + body 喂给 `gh pr create` | one-line title + multi-section body (Summary/Changes/Testing/Risk/Related) + reviewer suggestion | feature 分支 push 后, gh pr create 前手动派 |

## 第 6 个: release-notes (v0.9.1.0)

| Sub-agent | 职责 | 输出 | 何时触发 |
|---|---|---|---|
| **release-notes** | 聚合多 commit 为用户面 release notes (Highlights/Features/Fixes/Install/Breaking) | markdown 文本喂给 `gh release create --notes`; 链接 GitHub compare URL | git tag 前手动派 |

## 未来扩展

- `dep-bumper`: 决策依赖包升级时机
- `pr-reviewer`: 自动 review PR (区别于 anti-slacking-auditor 的 turn-level audit)

每个新 agent 应:
1. 加 `plugin/agents/<name>.md`
2. 职责单一, 不与既有重叠
3. Bash 只读白名单
4. 输出格式严格 (供 hook / 主 Claude 解析)
5. README.md 更新协作图
