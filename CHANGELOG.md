# Changelog

遵 SemVer 4 段制 `MAJOR.MINOR.PATCH.BUILD`。


## [0.17.0.0] - 2026-05-21

### Added (MINOR · /betterloop slash command 内置 + §10.4 自主停规则)

- **`plugin/commands/betterloop.md`** (新): /betterloop 命令模板进 plugin (之前用户得自己手放到 `~/.claude/commands/`, 现在 plugin 装好即用).
- **§10 退出协议加条件 D — 自主停止**: 之前只有用户明令 / 切项目 / quota 95% 三个退出路径, "原 prompt 提了完成条件" 的情况主 Opus 仍永不停息. 现在加条件 D:
  - "持续到 X 都被检查过且完全合理 / 做完 N 件事就停 / 全部修完结束" 等**明示完成态** → 达到即自主停
  - "永不停息 / 一直跑 / 持续迭代" 等**明示永续语义** → 仅 §10.1-3 退出, 绝不自主停
  - 无明确边界 (反复审查 / 持续优化 / 改完为止) 等**模糊态** → 倾向继续, auditor 在 Tick 1 计划组顺便判 "已达暗示完成态" 才允许自主停
- **新增 §10.4 详则**: 自主停判定 4 步模板 + 自主停退出动作 (落 loop-plan-组N-final.md + 简短结案报告 + 不调 ScheduleWakeup)
- **新增 "启动期意图识别" 段**: /betterloop 启动时主 Opus 必须先读 ARGUMENTS 提取停止语义, 第一轮回复就告知用户 "侦测到明示停止 / 永续 / 模糊态" 让用户能及早纠正解读.
- **`plugin.json`** 加 `"commands": ["./commands/"]` 让 plugin 系统挂载命令; keywords 加 `betterloop / autonomous-loop`.

### Why

之前 /betterloop slash command 在用户级 `~/.claude/commands/betterloop.md`, 装 plugin 不会自带, 用户得手动复制. plugin 应该把命令一起发. 同时之前 §10 "永不停息" 太绝对 — 用户在 ARGUMENTS 明示 "做完 X 就停" 时, 主 Opus 仍不能自主停, 必须用户重复明令 "停止", UX 差. §10.4 让主 Opus 有上下文感的退出权: prompt 含明示停止 → 自主停; 含明示永续 → 不停; 模糊态 → auditor 协助判.

### How to use

升级到 0.17.0.0 后:
- `/betterloop <任务>` 直接可用 (无需放本地 commands)
- 写 prompt 时如果想让 loop 自主结束, 加 "持续到 ... 完成" / "X 修完即停"; 想让永不停, 加 "永不停息" / "一直跑"
- 模糊态 (e.g. "反复审查 X" 无明确停止) 时, loop 倾向永续, 但每组 auditor 判达成态会触发自主停 → 兜底退出


## [0.16.0.0] - 2026-05-19

### Added (MINOR · 新增 betterloop-auditor subagent 配合 /betterloop 工作流)

- **`plugin/agents/betterloop-auditor.md`** (新): /betterloop slash command 计划组（Tick 1）专用工作量审查 subagent。每个 5+1+4 分组开头，主 Opus 4.7 规划完本组 4 个候选 tick 后**强制** dispatch 调用，按内置 6 问决策流逐项判 PASS/WEAK。
- 审查标准完整内嵌 subagent system prompt：
  - **§2.2 合格 5 模式**（A 新模块开发 / B 全新界面 / C 后端新交互 / D 跨层重构 / E 重大性能架构优化），每模式必备要素清单
  - **§2.3 量化护栏 4 条**（≥150 行 / ≥3 文件 / ≥30 min / ≥2 layer）
  - **§2.4 立即 WEAK 反例清单 12 类**（单 bug / 单组件替换 / 单文案 / 单样式 / 单变量重命名 / 单日志 / 单文档微改 / 单 import / 单测试 / 单 lint / 单依赖升级 / 单配置改）
  - **6 问决策流 + 实际验证步骤 + 标准化输出报告格式**
- `model=sonnet` 走 Sonnet 4.6 节 quota，避免主 Opus 反复复述长 prompt
- 工具白名单：`Read / Grep / Glob / Bash`（Bash 仅只读：git diff/log/status/show + ls/find/cat/wc/jq 等，禁所有写命令）

### Why

之前 /betterloop slash command 把审查 prompt 写死在主 Opus 调用 `Agent(subagent_type="general-purpose", prompt="...大段标准文本...")` 里。问题：
1. 主 Opus 每次启动 subagent 都需复述一遍标准 → 浪费主会话 token
2. 主 Opus 可能不遵循指令、prompt 文本出现变体 → 审查标准漂移
3. 审查标准更新需要同时改 slash command + 主 Opus 行为，维护成本高

提取为独立 subagent 后：
- 主 Opus 调用只需传**候选 tick 清单**（4 个），不传标准
- 标准在 subagent 系统提示里写死，不可被变体
- 标准升级只需改 subagent 一个文件

### Companion Files (不在本 repo 内)

- `~/.claude/commands/betterloop.md`（slash command 一键宏，调用本 subagent）— 由用户全局 commands 目录管理，独立于 plugin


## [0.15.0.0] - 2026-05-14

### Fixed (MINOR · 多 commit 漏审 bug — auditor 改为审"自上次 audited 以来"全部 commit)

- **`plugin/hooks/stop-anti-slacking.sh`**: 之前 block reason 中硬编码 `git diff --stat HEAD~1`，主 Claude 一轮内打多个 commit 时 auditor 默认仅看最后一个，前面 commits 漏审。修：触发 block 前读 `/tmp/fruity-audit-<sid>.last_audited_commit` + `git rev-parse --verify` 验证 SHA 仍在树内 → 算 `DIFF_RANGE=<sha>..HEAD`；不存在或无效时 fallback `HEAD~1`。block reason 用 unquoted heredoc 插值 `${DIFF_RANGE}`，`${SESSION}` 字面量用 `\${SESSION}` 转义保留供绕过提示。
- **`plugin/hooks/post-tool-mark-audited.py`**: verdict PASS/PASS_WITH_DEBT 时除写 `.audited` 标记，再记当时 HEAD 全 SHA 到 `last_audited_commit` 文件，供 stop hook 读取。

### Tested

- `bash -n` 通过
- `python -m py_compile` 通过
- 模拟脏 dirty + 假 SHA 的 dry-run: HEAD~1 fallback 正确触发，`${SESSION}` 字面量在 reason 内完整保留


## [0.14.0.0] - 2026-05-14

### Added (MINOR · 跨 turn dirty 残留 fix — 新 hook + Stop 滤条)

- **`plugin/hooks/user-prompt-mark-turn.sh`** (新): UserPromptSubmit hook，每条用户提交时写当前 epoch 到 `/tmp/fruity-audit-<sid>.turn_start`，标记本 turn 起始时刻。
- **`plugin/hooks/stop-anti-slacking.sh`** 增 stale-dirty 滤条: dirty 存在性检查后立即比较 `dirty.mtime` 与 `turn_start.mtime`，若 dirty 早于 turn_start → 视为前 turn 异步残留（subagent Bash 落盘竞争留下的孤儿）→ 自动清理 + 放行，不再误 block 下一 turn 的纯只读操作。
- **`plugin/hooks/hooks.json`** 注册新 UserPromptSubmit handler `fruity:user-prompt:mark-turn`，与既有 `skill-match-announcer` 并存。

### Why

旧版 bug: anti-slacking-auditor (subagent) 内部 Bash 调用走 PostToolUse → mark-dirty.sh，subagent 跑过的解释器命令仍写 dirty。这些写入与父 Stop hook 的清理存在竞争，dirty 落盘可能晚于 Stop 清理 → 留下孤儿 dirty → 下一 turn 即便只跑只读 `date` / `find` 也被强制要求 audit。

修复思路: 用 turn_start 时间锚 + mtime 比较，把"前 turn 异步残留"与"本 turn 真实改动"在 Stop 层区分。无 turn_start 文件时回退原行为（保守安全）。

### Tested

3 测试 case 全 pass:
1. 旧 dirty (mtime < turn_start) → 自动清理 + pass
2. 新 dirty (mtime > turn_start) → 仍 block，要求 audit
3. 无 turn_start (首 turn / 升级前 session) → 回退原行为 block


## [0.13.0.0] - 2026-05-13

### Added (MINOR · 真正移植 claude-quotas, 解除依赖)

- **`plugin/scripts/check-quota.sh`** (新): 移植自 `claude-quotas` v1.4.0 `src/lib.ts` 的核心逻辑, bash + curl + jq 实现。直接读 `~/.claude/.credentials.json` 的 OAuth token, 调 `https://api.anthropic.com/api/oauth/usage` API, 返回与 claude-quotas MCP 等价的 JSON。支持 `--json` / `--summary` / `--fivehour` / `--sevenday` / `--sevenday-opus` / `--sevenday-sonnet` / `--resets-in` 6 种输出模式。
- **`quota-aware-loop` SKILL 改造**: "前置依赖 claude-quotas plugin" → "自带实现, 无外部依赖"。优先用 `bash plugin/scripts/check-quota.sh`, 备选 claude-quotas MCP (功能等价, 任选其一)。
- **`post-tool-mark-dirty.sh` Bash 白名单扩展**: 加 `bash plugin/scripts/check-quota.sh` 和 `bash plugin/scripts/sync-better-memory.sh --check` 到只读白名单 — 这些查询脚本不再触发 audit。`curl/wget` 无 -o/-O/> 重定向也加入只读白名单。

### Removed

- **不再依赖 `claude-quotas` plugin**。可单独卸载 claude-quotas, fruity-skills 仍能完整工作。

### Note

- 与 claude-quotas 共存不冲突 (各做各的, Claude 自选)
- 若公网或 OAuth token 异常, check-quota.sh 退出码 2/3/4 + JSON error 提示


## [0.12.0.1] - 2026-05-13

### Changed (BUILD · 简化 hook 单一职责)

- `skill-match-announcer.sh` 回滚到 v0.11 静态注入版本, 去除关键词触发的 quota-aware 条件注入逻辑。理由: 保持 hook 单一职责 (仅注入 [ACK]+[SkillMatch]); quota 感知交由 `quota-aware-loop` skill 文档让 Claude 自主判断, 不在多处分散逻辑。
- `quota-aware-loop` skill **保留** (核心整合方式)。


## [0.12.0.0] - 2026-05-13

### Added (MINOR · 配额感知 + 整合 claude-quotas)

- **`plugin/skills/quota-aware-loop/SKILL.md`** (新 skill): 让 Claude 主动用 `claude-quotas` MCP `check_quota` 在 /loop / ScheduleWakeup / 长任务前节制。前置依赖 claude-quotas plugin。含决策表 (5h 80-95% / 7d 70-95% 多档) + delaySeconds 计算伪代码 + 与 anti-slacking-auditor 联动方案 + token 经济分析 (每天 ~3000 token 防止周末烧爆)。
- **`skill-match-announcer.sh` v0.12.0.0**: 条件注入 quota-aware 提示。检测 prompt 含 `/loop` / `ScheduleWakeup` / `继续做` / `跑完` / `长任务` / `部署` 等关键词时, 在 [ACK]+[SkillMatch] 之后追加 quota 检查铁律提示。普通 prompt 不注入 (token 经济)。

### Note · 架构

- Hook 内不能直接调 MCP tool (Claude Code 架构限制), 因此通过 (1) skill 文档指导 Claude 主动调 + (2) 关键词触发条件提示 双路径实现配额感知。
- claude-quotas plugin 独立维护, fruity-skills 仅引用其 MCP tool, 不重复实现 quota 拉取。


## [0.11.0.0] - 2026-05-13

### Added (MINOR · 评分体系 + 任务覆盖度 + bug 检测 + 逻辑链路审查)

`anti-slacking-auditor` 大改, 从 12 维度二元判定 → **15 维度百分制 + 5 档等级**。任何修改都严查 (不分阶段严苛度), 用户开发过程中持续把关。

**新增 3 维度**:
- 🔴 **`INTENT_COVERAGE_COMPLETE`** (critical, 8.5 分): 用户原话拆原子需求, 逐项核对兑现。缺一即 FAIL → BLOCKED。
- 🔴 **`NO_KNOWN_BUGS`** (critical, 8.5 分): bash -n / py_compile / jq / yaml + 空实现 / 偷懒话术 / 明显逻辑错探测。命中即 BLOCKED。
- 🟡 **`LOGIC_CHAIN_INTEGRITY`** (major, 5 分): 显式节点之间的隐含必需节点 (鉴权/重试/超时/离线/错误反馈/边界) 是否考虑。主 Claude 可明示"已知不做"豁免。

**Step 2 Intent Decomposition (新 step)**:
- A. 用户原话逐字拆显式原子需求 (编号)
- B. 推导隐含必需节点 (鉴权/重试/通信协议/断网恢复等)
- C. 输出 Intent 表供 Step 3 Coverage Map 逐项核对

**百分制 + 5 档等级**:

| 严重 | 维度数 | 单 dim 分 | 小计 |
|---|---|---|---|
| 🔴 critical | 7 | 8.5 | 59.5 |
| 🟡 major | 5 | 5 | 25 |
| 🟢 minor | 3 | 5 | 15 |
| **合计** | **15** | | **~100** |

| Status | 触发条件 | Stop hook 行为 |
|---|---|---|
| **PASS** | total ≥ 90 且 critical 全满 | 放行 |
| **PASS_WITH_DEBT** | 75-89 且 critical 全满 (第 3 iter 强制降级) | 放行 + warn |
| **WARN** ⭐新 | 60-74, 或 major 任一 FAIL 但 critical 全满 | 软警告, 仍 block 但弱 |
| **FAIL** | < 60 | 强制重审 (iter+1) |
| **BLOCKED** | critical 任一 < 8.5 | 永拦, 不计 iter 上限 |

**verdict 新格式**: `## Final Verdict: <status> [<score>/100 · iter N/<3|∞>]` (兼容旧格式无 score)

### Changed

- `plugin/hooks/post-tool-mark-audited.py` regex 兼容新 score 格式 + 新 WARN status; history.json 加 `score` 字段
- Step 5 编号下移 (Step 2 Intent / Step 3 Coverage / Step 4 Bug / Step 5 CLAUDE.md / Step 6 评分)
- "无简单/严格场景区分"明文写入 prompt — 用户开发过程中任何修改都严查
- `2-strike rule` 保留

### Note

- 已知不做的隐含节点: 主 Claude 在 Coverage Map 标注"explicit-skip: <reason>"豁免 `LOGIC_CHAIN_INTEGRITY` 扣分


## [0.10.0.0] - 2026-05-13

### Added (MINOR · B 方案 Bash 命令白名单细分)

- **`plugin/hooks/post-tool-mark-dirty.sh` 重写**: 由"任何 Bash 都写 dirty"细分为白名单判断:
  - **只读命令** (`ls`/`cat`/`grep`/`find`/`ps`/`free`/`git status/log/diff/show/blame/fetch/config/remote`/`docker ps/images/inspect`/`systemctl status/show/is-active`/`ufw status`/`gh xxx list/view/status`/`curl/wget` 无 -o/-O/>) → **不写 dirty, 不触发 audit**
  - **写入/危险/未知命令** (`rm`/`cp`/`mv`/`git commit/push/rebase`/`systemctl restart`/`docker run`/`ufw disable`/解释器/未知 token) → **写 dirty, 触发 audit**
  - **Write/Edit/MultiEdit 不变**: 总是写 dirty (保留 v0.9.x 行为)
- **测试 41 → 56 用例**: 新增 15 条 B 方案场景 (7 条只读放行 + 6 条写入触发 + 1 条未知保守触发 + 1 条 Write 仍触发)

### Why

简单问题 (`ls /tmp` / `free -h` / `git status`) 不再被 anti-slacking-auditor 误审, 减少 ~80% 假阳性 audit; 危险命令 (`rm -rf` / `git commit`) 仍被 auditor 守门, 保留反偷懒卖点。**保守默认**: 未知命令一律触发 audit, 宁可多审不漏审。


## [0.9.1.2] - 2026-05-13

### Fixed (BUILD · plugin install schema 修)

- `plugin/.claude-plugin/plugin.json` 去 `agents` 字段 (Claude Code schema 不允许; `agents/` 目录由 Claude Code 自动发现, 与 ECC 一致只写 skills/commands)。修后 `claude plugin install fruity-skills@fruity-skills` 通过校验。


## [0.9.1.1] - 2026-05-13

### Changed (BUILD · 收尾文档)

- **README "启用 GitHub Actions CI" 节**: 文档化 `.github/workflows/test.yml` 一直在工作树但未推送的原因 (gh OAuth token 默认缺 `workflow` scope), 给出 `gh auth refresh -s workflow` + push 三步骤。


## [0.9.1.0] - 2026-05-13

### Added (PATCH · 第 6 个 sub-agent)

- **`plugin/agents/release-notes.md`**: 读 `git log <prev-tag>..HEAD` + CHANGELOG, 输出用户面 release notes markdown (Highlights / Features / Fixes / Breaking / Install / Full Changelog 链接), 供 `gh release create --notes` 直接消费。与 changelog-writer 区别: 后者写 dev-facing CHANGELOG.md 段, 前者写 user-facing release notes (按"用户能感知的影响"分组, 跨多 commit 聚合)。
- **`plugin/agents/README.md` 协作图**: 含 release-notes 条目, 未来扩展去掉已实现项保留 dep-bumper / pr-reviewer。


## [0.9.0.0] - 2026-05-13

### Added (MINOR · 第 5 个 sub-agent 完成 commit/PR 闭环)

- **`plugin/agents/pr-creator.md`**: 第 5 个 sub-agent, 读 `git log main..HEAD` + diff + 现有 PR 模板 (如有), 输出可直接喂给 `gh pr create` 的 title + body markdown。补全 5 阶 commit/PR 工作流: auditor + version-bumper + changelog-writer + commit-msg-writer + pr-creator。
- **`plugin/agents/README.md` 更新**: 新增 pr-creator 条目, 未来扩展清单去掉已实现项, 保留 release-notes / dep-bumper。

### Note

pr-creator 输出 PR body 不复制 CHANGELOG (那是 changelog-writer 的领域); body 给 reviewer 一眼看懂 + 风险评估 + 测试 checklist。


## [0.8.0.1] - 2026-05-13

### Changed (BUILD · 文档)

- **`plugin/agents/README.md`** (新): 四件套 sub-agent 协作图 + 职责矩阵 + 红线归属表 + 主 Claude 标准 commit 流程模板。说明 anti-slacking-auditor / version-bumper / changelog-writer / commit-msg-writer 互不重叠、各司其职。


## [0.8.0.0] - 2026-05-13

### Added (MINOR · commit 工作流闭环 + 身份/发布红线)

- **`plugin/agents/commit-msg-writer.md`** (新 sub-agent): 生成 Conventional Commits 格式 commit msg。完成 commit 工作流四件套 (anti-slacking-auditor + version-bumper + changelog-writer + commit-msg-writer)。输出 one-liner / multi-line / reasoning, **绝不**含 Co-Authored-By trailer。
- **PreToolUse 新增 5 类 git/publish 红线**:
  - `git config user.name|user.email` 改成非 FruityMaxine 身份 → block (除非显式含 FruityMaxine/donaldholmestte@gmail.com)
  - `git remote set-url origin` 改到非 FruityMaxine 仓 → block (除非含 `github.com[:/]FruityMaxine/` 或 `x-access-token:` token URL)
  - `npm/yarn/pnpm publish` → block (个人项目不应公开发布)
  - `pip upload` / `twine upload` / `cargo publish` / `docker push` → block
  - `gh release create/edit/delete` → block (公开发布需确认)
- **测试 36 → 41 用例**: 5 条新 git/publish 红线 + 1 条 git config FruityMaxine 邮箱放行验证


## [0.7.0.0] - 2026-05-13

### Added (MINOR · 2 个新 sub-agent + 4 类新 secret 红线)

- **`plugin/agents/version-bumper.md`**: 决策 VERSION 升哪段 (MAJOR/MINOR/PATCH/BUILD) 的 sub-agent。读 git diff + commit 草稿 + 当前 VERSION, 给推荐 + 一句话理由 + 右侧归零后的新版本号。配合 anti-slacking-auditor 的 VERSION_BUMP 维度避免升错。
- **`plugin/agents/changelog-writer.md`**: 生成 Keep-a-Changelog 格式段落的 sub-agent。读 git diff + 新版本号, 输出可直接插入 CHANGELOG.md 顶部的 markdown 文本。配套 version-bumper 形成 commit 三件套 (auditor + bumper + writer)。
- **PreToolUse 新增 4 类 secret 红线**:
  - DB 连接串嵌入密码 (`mongodb://user:pass@`, `postgres://`, `mysql://`, `redis://`, `amqp://`)
  - Slack token (`xoxb-/xoxp-` 严格 4 段格式)
  - Google API key (`AIza` + 35 字符)
  - 硬编码 env 字面 (`JWT_SECRET=`/`SESSION_SECRET=`/`DJANGO_SECRET_KEY=` 等 + 16+ 字符值)
- **测试 32 → 36 用例**: 新增 3 条 secret 红线 + 1 条 DB URL 无密码放行验证

### Note

- Slack/Google 红线模式严格匹配真实 token 格式 (mock 字符串需符合规范长度才会被拦, 这是设计预期不是 bug)


## [0.6.0.0] - 2026-05-13

### Added (MINOR · PreToolUse 红线扩展 + 测试到 32 用例)

- **PreToolUse 新增 6 类红线** (`pre-tool-critical-redline.py`):
  - `curl|bash` / `wget|bash` 远程脚本管道执行 (供应链注入向量)
  - `ufw disable` / `ufw reset` / `ufw --force reset` (防火墙清空)
  - `iptables -F` / `iptables --flush` (防火墙规则全清)
  - `chmod -R 777 /etc|/var|/usr|/opt|/` (系统目录权限消除)
  - fork bomb 模式 `:(){:|:&};:`
  - `shutdown` / `reboot` / `init 0|6` (系统重启)
  - `history -c` / 清 `.bash_history` (痕迹清除)
- **测试 23 → 32 用例**: 新增 6 条红线测试 + 2 条正常路径放行 + 1 条 sync 脚本 --check 模式

### Note

红线检测在 hook 拦截层, 用户明确请求时仍可用 stop_hook_active=true 路径或显式 prompt 表明意图绕过。


## [0.5.0.0] - 2026-05-13

### Added (MINOR · 文档扩展)

- **`plugin/skills/fruity-rules/SKILL.md` 扩展**: 从 2K 字节扩到完整红线详解 (10 条规则展开 + 红线优先级层级). 含 VERSION 4 段升号细则 / Co-Authored-By 整改流程 / 偷懒话术黑名单 / Playwright UI 实测脚本模板 / systemd 行尾注释陷阱演示 / 后端 bind 规则 / :28xxx UFW 联动 / token Cookie 三段守门 / 全中文规则 / 文言文 ACK 触发规则。
- **`docs/examples/audit-report-pass.md`**: anti-slacking-auditor PASS 报告样板, 含完整 Step 0-5 + 12 维度评分表 + Coverage Map + Slacking Hits + Final Verdict 字段示例。
- **`docs/examples/audit-report-fail.md`**: FAIL → BLOCKED 样板, 演示 (1) 第 1 次 audit critical FAIL 直接 BLOCKED, (2) 第 2 次 2-strike rule 让 major 维度自动升 critical, (3) 三档绕过对 critical 失效。
- **README badges**: CI status / version / license / tests pass count 四个 shield.io / GitHub Actions badge。

### Changed

- README 版本号 0.2.0.0 → 0.5.0.0 (此前漏同步)


## [0.4.0.0] - 2026-05-13

### Added (MINOR · PreToolUse 红线拦截 + GitHub Actions CI)

- **PreToolUse 红线拦截 hook** (`plugin/hooks/pre-tool-critical-redline.{sh,py}`): 事前拦截 critical 违规, 不等 anti-slacking-auditor 事后审。matcher: `Write|Edit|MultiEdit|Bash`。拦截 6 类:
  - Bash: `git commit` 含 `Co-Authored-By` trailer
  - Bash: `git push --force/--no-verify` 到 main/master
  - Bash: 危险 `rm -rf /` / `mkfs` / `dd of=/dev/sd*`
  - Write/Edit: 内容含 `listen|bind|host 0.0.0.0`
  - Write/Edit: 内容含 AWS / GitHub PAT / OpenAI / PEM private key 字面值
  - Write/Edit: `.service` 文件含行尾中文注释 (systemd 静默忽略陷阱)
  命中输出 `decision=block + reason`, 主 Claude 立即修改后重试。
- **GitHub Actions CI** (`.github/workflows/test.yml`): push/PR 到 main 自动跑 jq 校验 + bash -n + py_compile + 完整 23 用例测试套件。
- **测试扩展**: 15 → 23 用例 (新增 8 个 PreToolUse 红线场景 + 正常路径放行验证)

### Changed

- `hooks.json` 新增 PreToolUse 注册条目 `fruity:pre-tool:critical-redline`


## [0.3.0.0] - 2026-05-13

### Added (MINOR · 测试套件 + LICENSE)

- **`plugin/tests/run-tests.sh`**: 端到端 hook 测试套件 (15 用例): skill-match-announcer 注入校验 / post-tool-mark-dirty 写 .dirty / post-tool-mark-audited PASS/FAIL/其他 sub-agent 三路径 / Stop hook 无 dirty/有 dirty 无 audited/有 dirty 有 audited 三路径 / BLOCKED 永拦 / 三档绕过 (env var/skip flag/keyword) / stop_hook_active 死循环防护
- **`LICENSE`** (MIT): README 已声明但缺文件 (doc/file drift), GitHub 现可自动识别 license badge
- **`plugin/hooks/post-tool-mark-audited.py`**: 把 Python 逻辑拆到独立文件; .sh 改一行 wrapper

### Fixed (Critical silent bug)

- **post-tool-mark-audited hook 之前在所有机器都默默失败**: 原 `python3 - <<PY ... raw='''$INPUT''' ... PY` 写法的 heredoc 把脚本本体作为 stdin 给 python, 同时 shell 把 `$INPUT` 展开到 python 三引号中 — 多行 JSON 触发 `raw=` 提前闭合, json.loads 解析失败被 except 静默吞掉, **整个 hook 退出 0 但什么都没写**。表现: anti-slacking-auditor 即便 PASS 也不会写 .audited flag, 主 Claude 永远卡在 Stop block。本版用独立 .py 文件 + cat 管道传 stdin 修复。测试 12→15 通过证明修复有效。

## [0.2.2.0] - 2026-05-13

### Changed (MINOR · sub-agent 设计重做)

经 **2 轮 × 3 视角 sub-agent harness-construction 评审** 重设计 `anti-slacking-auditor`:

- **Bash 白名单** (文档硬约束): 仅允许 git diff/log/status/show/blame、jq、bash -n、python3 -m py_compile、wc、stat、find/head/tail/cat/ls。禁 rm/mv/cp/commit/push/systemctl/docker/gh 等带副作用命令。
- **Step 0 历史读取**: auditor 启动必读 `/tmp/fruity-audit-history-<sid>.json` (PostToolUse hook 维护, auditor 不可写)。2-strike rule: 同 fail_dim 连续 2 次 → 升级 critical。
- **Step 1 强制 git diff**: 必跑 `git log -20 + git diff --stat HEAD~1` 作前置事实采集, 不允许直接 Read 文件就下结论。
- **双因子激活门**: 维度按 (file_types ∩ dim.file_patterns) OR (用户原话 ∩ dim.keywords) 激活, 未激活 → N/A 算 PASS。
- **三级 severity**:
  - 🔴 **Critical 红线** (硬循环不计 iter, 绕过无效): NO_CO_AUTHOR / NO_BIND_0000 / NO_SYSTEMD_INLINE_COMMENT / REPLY_FULL_CHINESE / NO_LEAKED_SECRETS
  - 🟡 **Major** (1 次 FAIL = FAIL, 走 3-iter 上限): VERSION_BUMP / UI_PLAYWRIGHT_TESTED / UFW_FOR_NEW_PORT / TOKEN_COOKIE_GATING
  - 🟢 **Minor** (累计 ≥2 才 FAIL, 单项 WARN): INDEX_MD_SYNC / COMMIT_TITLE_VERSION / DOC_CODE_SYNC
- **3-iter 上限 + PASS_WITH_DEBT 降级**: 第 3 次仍 FAIL 且非 BLOCKED → 强制 PASS_WITH_DEBT 列剩余清单, 主 Claude 可结束 turn。BLOCKED (critical) 不计上限。
- **verdict 格式带 iter**: `## Final Verdict: <PASS|PASS_WITH_DEBT|BLOCKED|FAIL> [iter N/3 或 N/∞]`

### Added

- **三档绕过机制** (仅对 major/minor, critical 无效):
  - `FRUITY_NO_AUDIT=1` env var (整 session 关)
  - 用户原话含 `[skip-audit]` / `别审了` / `跳过审核` / `不用审`
  - `touch /tmp/fruity-audit-<sid>.skip` flag (单次, 用完删)
- **`plugin/scripts/sync-better-memory.sh`**: 从公共仓拉最新 SKILL.md 同步内置副本; `--check` 模式仅检测漂移不写入
- **`post-tool-mark-audited.sh` 升级**: 追加 tick 到 history.json (含 commit_head, fail_dims, verdict, iter); 仅 PASS/PASS_WITH_DEBT 写 .audited flag

### Fixed

- BLOCKED 状态在 Stop hook 永拦, 不受 .skip / env var 影响; 防止 critical 红线被绕过

## [0.2.1.0] - 2026-05-13

### Fixed (PATCH · 关键缺陷修复)

- Stop hook 从 `tail -n 200 + grep "Write|Edit|Bash"` 启发式改为 PostToolUse flag 结构化判断
- 新增 `plugin/hooks/post-tool-mark-dirty.sh` 和 `post-tool-mark-audited.sh`

## [0.2.0.0] - 2026-05-13

### Added (MINOR · 新功能整合)

- 整合 better-memory v1.3.0.2 SKILL.md 作为内置 skill
- anti-slacking-auditor v1 (基于 ECC code-explorer 5 步探索骨架)
- UserPromptSubmit hook 合并 [ACK] + [SkillMatch]

## [0.1.0.0] - 2026-05-13

### Added

- 项目骨架: marketplace.json + plugin.json + VERSION
- 初版 anti-slacking-auditor / hooks / 示例 skill fruity-rules
