---
description: 严格纪律的 /loop 自主迭代 — 5+1+4 节奏、单 tick MINOR 工作量硬标准、强制实测、subagent 审查、95% quota 永不停息。一键启动 /loop dynamic mode 并应用以下全部 10 节规则。
---

# /betterloop — 严格纪律的 /loop 自主迭代

收到此命令的主 Opus 4.7 **立即**按以下顺序执行，**不允许跳过**：

```
Step 1 → 启动 /loop dynamic mode（命令的核心动作）
Step 2 → 应用以下完整工作协议（§1-10）
Step 3 → 进入第一轮 tick
```

---

## Step 1 ▸ 启动 /loop dynamic mode（必先做）

调用 Skill 工具触发 `loop` skill，**不指定 interval**（dynamic 自步模式），让 Claude 按 §5 quota 状态自决 ScheduleWakeup 间隔。

> 本命令后续 §1-10 全部规则只在 loop 已启动的前提下才有意义。**Step 1 不做 = 后面全废**。

---

## Step 2 ▸ 应用以下完整工作协议

**适用范围**：当前 shell 工作目录所指向的项目。skill §7 自动按项目主语言/栈匹配技术 skill。

**永不停息**：除非用户明令"停止 loop"，或 5h quota ≥ 95%（跳到下个 reset 后续跑）。

---

### §1. 核心节奏 — 5+1+4 分组循环

```
组 N (5 个 tick):
  ├─ Tick 1  [计划组]
  │   ├─ 总结上组（组 N-1）实际工作量 & 完成度
  │   ├─ 规划本组 4 个执行 tick 的具体任务
  │   ├─ dispatch subagent 评估任务工作量是否符合 §2 标准
  │   ├─ subagent 判 WEAK → 主 Opus 重规划直至全 PASS
  │   └─ 落盘 docs/progress/loop-plan-组N.md
  ├─ Tick 2-5  [执行组] = 实现 + 实测 + commit + 修改记录

→ 进入组 N+1，循环往复。
```

#### 计划组（Tick 1）必做

1. 读 `docs/progress/loop-plan-组(N-1).md` + 本组涉及的 commits → 评估上组完成度
2. 列本组 4 个任务（每对应一个执行 tick），每个必须达 §2 标准
3. **强制 dispatch `betterloop-auditor` subagent**（审查标准已写死在 subagent 内，主 Opus 只传候选清单）：

```
Agent(subagent_type="fruity-skills:betterloop-auditor",
      prompt="""# 组 N Tick 1 候选清单

               ## Tick 2 候选
               - 标题: <一句话总结>
               - 命中模式（A-E 自评）: <如 A. 新模块开发>
               - 技术方案: <方案要点 3-5 句>
               - 文件清单: <逐个列出，标注新建/修改>
               - 预估改动行数: <数字>
               - 预估涉及 layer: <列出>
               - 预估时长: <分钟>

               ## Tick 3 候选
               [同上结构]

               ## Tick 4 候选
               [同上结构]

               ## Tick 5 候选
               [同上结构]

               请按你内置的 6 问决策流逐项审查，返回标准报告格式。""")
```

> **不要在 prompt 里重复审查标准** — `betterloop-auditor` 的 system prompt 已经完整内嵌 §2 全部规则（合格模式 / 量化护栏 / 反例清单 / 6 问决策流）。主 Opus 只负责"列候选"，审查标准由 subagent 自带。

4. subagent 全 PASS 才允许进入 Tick 2；任一 WEAK → 主 Opus 按建议**放大任务 scope**（合并相关活、扩边界）后重审，循环到全 PASS
5. 落盘 `docs/progress/loop-plan-组N.md`（含上组总结 + 本组规划 + subagent 审查结论）

#### 执行组（Tick 2-5）必做

每个执行 tick **完整闭环**：
1. 读 `docs/progress/loop-plan-组N.md` 拿到本 tick 任务
2. 实现改动（代码 + UI + 配置）
3. **强制实测**（按改动类型，见 §3）
4. 实测产物（截图 / curl 响应 / 日志）**实际 Read 验证**
5. commit + 版本号 bump（按用户全局规则 SemVer 4 段）
6. 追加 `docs/progress/修改记录_YYYY-MM-DD.md`
7. 决定下个 tick ScheduleWakeup 间隔（按 quota，见 §5）

---

### §2. 单 Tick 工作量硬标准 — "独立可发版的项目升级"

#### 2.1 总原则

**每个执行 tick 必须是一次"独立可发版的项目升级"**，即同时满足：

1. **业务价值独立**：完成后可单独写一行 commit / changelog 公告，对外作为新增能力宣告
2. **版本号至少 MINOR 级**：单 tick 产物对应 SemVer 升级 **必须 ≥ MINOR**（即 `vX.Y.0.0` 而非 PATCH `vX.Y.Z.0` 或 BUILD `vX.Y.Z.W`）

**绝不允许**把"顺手 30 分钟内完事的小活"作为 loop tick 计划。这种活塞进日常 commit 即可，**不配占一个 loop tick**。

#### 2.2 合格 Tick 的 5 种模式（至少满足一种）

| # | 模式 | 必备要素（全部具备）|
|---|---|---|
| **A** | **新模块开发** | 跨 ≥5 文件 · 新增 ≥1 domain entity / service / repository · 含 input→process→persistence→output 完整数据流 · 含至少 1 个新 endpoint 或新 view |
| **B** | **全新功能界面** | ≥1 个新 route / 新页面 · ≥3-5 个**新**组件（不是替换已有的）· 新状态管理或新数据 fetching 逻辑 · 完整交互闭环 |
| **C** | **后端新交互逻辑** | 新 endpoint / 新 service method · 新业务规则 · DB schema 变化 OR 跨表 join 逻辑 · 至少 1 个新 model |
| **D** | **跨层重构** | ≥5 文件改动 · 影响多个 architecture layer · 改完 verify 全链路不破 · 重构前后有明确架构图/对比 |
| **E** | **重大性能/架构优化** | 量化指标改善（延迟 / 内存 / 包体 / 复杂度）· 跨 ≥3 文件 · 含 before/after 测量数据 |

#### 2.3 量化护栏（任一未达 → 计划组 subagent 必判 WEAK）

| 指标 | 下限 |
|---|---|
| 改动行数（新增/修改/删除合计）| **≥ 150 行** |
| 跨文件数（不含锁文件 / generated）| **≥ 3 文件** |
| 主 Opus 实际推理时长（估算）| **≥ 30 min** |
| 涉及 architecture layer 数 | **≥ 2 层**（UI/API/Domain/Persistence/Infrastructure 算不同层）|

#### 2.4 立即 WEAK 的反例清单（计划组规划阶段就拒）

| 反例类型 | 具体例子 |
|---|---|
| **单 bug 修复** | 修一个 null pointer / off-by-one / typo error |
| **单组件 UI 替换** | 把 Button A 换成 Button B / 换一个 icon |
| **单文案修改** | 改一个标题 / 一段提示文本 |
| **单样式调整** | 改颜色 / 边距 / 字号 / 圆角 |
| **单变量重命名** | `foo` → `bar` 跨几文件全局替换 |
| **单日志补充** | 加几个 console.log / print / logger.info |
| **单文档微改** | 改 README 一行 / 补一个 docstring |
| **单 import 整理** | 删 unused / 排序 / 拆 barrel |
| **单测试补充** | 加一个 test case / 一个 assertion |
| **单 lint/format** | 仅跑 prettier / black / gofmt |
| **单依赖升级** | 仅升一个 package 版本（除非 major 破坏性升级需配套改）|
| **单配置改** | 改一个 env var / 一行 yaml |

这些**统一归类为"日常维护"**，应在执行其他合格 tick 时**顺手带做**，不允许作为独立 tick。

#### 2.5 决策流（计划组规划每个 tick 时走一遍）

```
对每个候选任务问 6 个问题:
  1. 是否落在 §2.2 五种合格模式之一？        →  否 = WEAK
  2. 是否同时满足 §2.3 全部 4 条量化护栏？    →  任一否 = WEAK
  3. 是否落在 §2.4 反例清单？                →  是 = WEAK
  4. 完成后可否单独写一行对外公告？           →  否 = WEAK
  5. 对应版本号升级是否 ≥ MINOR？             →  否 = WEAK
  6. 主 Opus 估算时长是否 ≥30 min？           →  否 = WEAK

  6 问全 PASS  →  允许进入本组规划
  任一 WEAK    →  重新放大任务（合并相关活、扩 scope）或换一个任务
```

#### 2.6 主 Opus 执行中自检

执行 tick 进行到一半发现"提前做完了"或"产物落到反例区"→ **立即追加工作量**到达标，**绝不"完了"上报骗人**。可行的追加方向：

- 扩展到模式 A-E 中相邻模式
- 把"顺手能做"的反例小活打包进本 tick
- 加完整测试覆盖（unit + integration + E2E 三层）
- 加完整文档（API spec + user guide + architecture diagram）

---

### §3. 强制实测协议（铁律）

**严禁只改不测、严禁无证据 UI 改动、严禁空 loop。**

#### 按改动类型映射实测方法

| 改动类型 | 实测方法 |
|---|---|
| Web/移动 UI | Playwright async API（headless chromium bundle）截图 + Read 截图 |
| 用户交互（按钮 / 表单 / 路由）| Playwright **真实点击/输入** + 验证响应/导航 |
| API / 后端 endpoint | `curl` 或 `httpie` 调用 + 验证 response body/status |
| 数据库迁移 | `psql` / `sqlite3` 实查目标表确认 schema/data 已变 |
| CLI / 脚本工具 | 真实运行命令 + 验证 stdout / exit code |
| 配置 / 部署 / systemd | 重启服务 + 公网 IP（或目标 host）curl `/healthz` |
| 库/算法 | 写最小 reproducer 跑通 + assert 关键属性 |
| Native mobile（Android/iOS）| 模拟器跑 + 截图 / instrumented test |

#### Playwright 实测标准方法

按用户 `/root/.claude/CLAUDE.md` 前端调试段：
- `.venv/bin/python` + Playwright async API
- `headless=True` + `--no-sandbox` + `--disable-dev-shm-usage`
- 用 Playwright 自带 chromium bundle（**不用 snap / system chromium**）
- 截图存 `/tmp/<tick-id>-<page>.png` → 用 Read 工具读图实际确认

#### 实测失败的处理

- 实测产物显示异常 → **本 tick 不算完成**，回头修，直到产物符合预期
- 不许"代码改完了但没法实测 → 当作完成"
- 不许"截图看着差不多 → 当作完成"，看到任何异常立刻修

---

### §4. Subagent 使用准则

#### 必用 subagent 场景

- **计划组（Tick 1）工作量评估** — 强制
- 大批文件 review（≥5 文件）— 用项目主语言对应 reviewer agent
- 死代码清理 — `everything-claude-code:refactor-cleaner`
- 文档同步 — `everything-claude-code:doc-updater`
- 静默失败审查 — `everything-claude-code:silent-failure-hunter`
- 并行重构（≥3 不重叠文件）— 多 worker 并发

#### 主 Opus 自做 vs subagent 派发判断

| 场景 | 选择 |
|---|---|
| 单文件 < 100 行改动 | 主 Opus 自做（dispatch 开销不划算）|
| 跨 ≥3 文件改动 | 派 1-3 个 Sonnet 4.6 worker 并发（文件域不重叠）|
| 需要项目全貌判断 | 主 Opus 自做（4.7 上下文最完整）|
| 重复性批量改动 | 派 N 个 worker 并发 |
| review / audit | 派 specialized subagent |

#### Subagent 启动铁律

- ✅ 必须 `Agent(model="sonnet", ...)` 显式写 sonnet（→ Sonnet 4.6，省 quota）
- ✅ Brief 必含 **WHY + scope + 边界**（防理解偏，参考 `/agentswarm` 命令模板）
- ❌ 禁用 `claude -p` / `claude-devfleet` / `Equality-Machine/claude-p`（计费坑/封号风险）

---

### §5. Quota 与永不停息

#### 不可跳过原则

- **5h quota 用到 95% 以上**才允许跳过当前 tick 等待下一 5h reset
- 95% 以下 → 即使感觉"没事做了" → 主动找事（按 §6 任务挖掘）
- **唯有用户明令"停止 loop"**才能真停（用户 memory `feedback_loop_permanence.md`）

#### ScheduleWakeup 间隔

| Quota 状态 | 下次 wakeup |
|---|---|
| < 80% | 270s（保持 prompt cache 热）|
| 80%-94% | 270s（继续做，prompt 控制更精炼）|
| 95%-99% | 跳到下个 5h reset（计算秒数后 ScheduleWakeup）|
| Weekly quota 紧 | 见 `fruity-skills:quota-aware-loop` |

每次 ScheduleWakeup 前**强制调用** `check_quota` MCP tool。

---

### §6. 任务挖掘 — "loop 觉得没事做"时

主 Opus 自检发现"好像没活了" → **绝不允许空 loop** → 按以下顺序找事：

1. 读项目 `HANDOFF.md` / `TODO.md` / `docs/progress/` 找遗留任务
2. grep `TODO / FIXME / XXX / HACK` 全项目
3. 派 `Agent(subagent_type="code-explorer", model="sonnet")` 扫项目找：
   - 静默失败点（try-except 没记日志的）
   - dead code / unused import
   - 测试覆盖空白
   - 文档与代码不一致点
   - Accessibility 缺失
   - 安全隐患（用 `everything-claude-code:security-review` skill）
4. 派 deep-research subagent 调研同类产品实用功能 → 选 1-2 个补
5. 依然找不到 → 列 5-10 个"如有时间该做"清单，subagent 评估优先级，取最高 1 个做掉

绝不允许"实在没事做了 sleep 1h"摸鱼。

---

### §7. 全程匹配 skill 寻找任务

每个执行 tick 开工前**先做 skill 扫描**：

| 项目栈 | 对应 skill |
|---|---|
| React/Next.js | `everything-claude-code:frontend-patterns` + `nextjs-turbopack` + `frontend-design` |
| Vue/Nuxt | `everything-claude-code:nuxt4-patterns` + `frontend-design` |
| Android Kotlin | `everything-claude-code:kotlin-patterns` + `android-clean-architecture` |
| Compose MP | `everything-claude-code:compose-multiplatform-patterns` |
| iOS Swift | `everything-claude-code:swiftui-patterns` + `swift-concurrency-6-2` |
| Flutter | `everything-claude-code:dart-flutter-patterns` |
| Python | `everything-claude-code:python-patterns` + `python-testing` |
| Go | `everything-claude-code:golang-patterns` + `golang-testing` |
| Rust | `everything-claude-code:rust-patterns` + `rust-testing` |
| Spring Boot | `everything-claude-code:springboot-patterns` + `springboot-tdd` |
| Django | `everything-claude-code:django-patterns` + `django-tdd` |
| Laravel | `everything-claude-code:laravel-patterns` + `laravel-tdd` |
| NestJS | `everything-claude-code:nestjs-patterns` |
| Ktor | `everything-claude-code:kotlin-ktor-patterns` |
| 数据库 | `everything-claude-code:postgres-patterns` / `clickhouse-io` + `database-migrations` |
| Docker / 部署 | `everything-claude-code:docker-patterns` + `deployment-patterns` |
| 安全审查 | `everything-claude-code:security-review` |
| 性能优化 | `everything-claude-code:benchmark` |
| E2E 测试 | `everything-claude-code:e2e-testing` |
| 通用 TDD | `superpowers:test-driven-development` + `everything-claude-code:tdd-workflow` |

---

### §8. 强制版本号 + 修改记录

- 每个 tick 至少 1 个 commit
- 每个 commit 必带版本号 bump（SemVer 4 段，右零归零规则，混合改动按最大段升）
- Commit 第一行格式：`<type>(<scope>): vX.Y.Z.W <一句话描述>`
- 同 tick 追加 `docs/progress/修改记录_YYYY-MM-DD.md`（不攒到组末写）
- **禁** Co-Authored-By trailer / "Generated with Claude Code"

---

### §9. 主 Opus 每 tick 自检清单

退出本 tick 前必须答清，任一 No → 不允许 ScheduleWakeup：

- [ ] 工作量是否达 §2 标准（合格模式 + 量化护栏 + 不落反例）？
- [ ] 所有改动是否按 §3 类型映射做了实测？
- [ ] 实测产物（截图 / response / log）是否实际 Read 验证过？
- [ ] 版本号是否 bump 且 commit 已落？
- [ ] `docs/progress/修改记录_今日.md` 是否追加？
- [ ] 若是计划组：subagent 是否 PASS 了工作量审查？
- [ ] 下次 ScheduleWakeup 间隔是否查过 quota？

---

### §10. 退出协议

唯有以下**四种**情况允许结束 loop：

1. 用户明示 "停止 loop" / "停" / "退出 betterloop"
2. 用户明示切换到其他项目（且明示"停当前 loop"）
3. 5h quota ≥ 95% → ScheduleWakeup 跳到 reset，reset 后自动续跑（不算真"停"）
4. **原 prompt 含明示停止条件且实际达到** → 主 Opus 自主停（无须再问用户）

#### §10.4 自主停止判定细则（关键 — 客观/主观停止条件分轨）

> ⚠️ **铁律**：当用户在 ARGUMENTS 中明示了**客观边界明确**的停止条件（绝对时间、明确数量、明确完成项),主 Opus **绝对不得**主观更改 / 忽略 / 提前停止;**没活也不能空 loop**,自己去找活干。
> 唯有当用户给出的是**主观停止权限**（"你觉得 X 就停" / "你认为做完了就停")时,Opus 才被允许自主停。
> **历史教训**：2026-05-22 主 Opus 在用户明示"永不停歇直到北京 12:00"的情况下,自作主张提前 3 小时停 loop —— 严重违规。

启动 loop 时主 Opus 必须先读原始 ARGUMENTS,把停止条件**分轨**到下表四档之一:

| ARGUMENTS 形态 | 类别 | loop 行为 | 例 |
|---|---|---|---|
| 客观时间边界(`UTC HH:MM` / `北京 HH:MM` / `N 小时后` / `YYYY-MM-DD HH:MM`) | **A. 客观时间停** | 守到该时刻才停,**绝不提前**；活完用 §6 找活 | "永不停歇直到北京 12:00" |
| 客观数量/状态边界("做完 N 件事就停" / "把 X 改成 Y 即可" / "全部修完结束" / "持续到 X 都被检查过且完全合理") | **B. 客观完成停** | 全部达成即停;**未全达成不得停**;主 Opus 不得主观判定"已经够了" | "把 5 个 bug 修完即停" |
| 主观授权停("你觉得 X 就可以停" / "你认为做完了就停" / "看你判断") | **C. 主观授权停** | Opus 自主判断,可达成即停 | "你认为做完了 你就可以自主停止" |
| 永续语义("永不停息" / "一直跑" / "持续迭代" / "不要停") | **D. 明示永续** | 仅 §10.1-3 退出,**绝不自主停** | "持续优化, 不要停" |
| 无任何明示边界 | **E. 模糊态** | 倾向继续;auditor 判"已达暗示完成态"才允许自主停 | "持续优化项目" |

#### 关键差异 · A/B 客观停 vs C 主观停

| 维度 | A/B 客观停 | C 主观授权停 |
|---|---|---|
| 谁决定何时停 | **用户**(时刻 / 数量 / 状态 已定义) | **Opus 自己** |
| Opus 是否可提前停 | **❌ 严禁** | ✅ 允许 |
| 活完后行为 | **必走 §6 找活**;绝不空 loop | 可结案停 |
| 误判后果 | 用户怒喷"违反规则" | 通常可接受 |

#### A/B 客观停 · "没活了"时主 Opus 必做(永不空 loop)

按以下顺序找活,**找到就做,绝不允许"我觉得做完了"提前停**:

1. 读项目 `HANDOFF.md` / `TODO.md` / `docs/progress/` 找遗留任务
2. grep `TODO / FIXME / XXX / HACK` 全项目
3. 派 `Agent(subagent_type="everything-claude-code:code-explorer", model="sonnet")` 扫:
   - 静默失败点(try-except 没记日志的)
   - dead code / unused import / 重复代码
   - 测试覆盖空白(用 pytest --cov / vitest coverage 量化)
   - 文档与代码不一致点
   - Accessibility(WCAG)缺失
   - 性能瓶颈 (慢查询 / N+1 / 包体过大)
4. 派 `everything-claude-code:security-reviewer` / `everything-claude-code:typescript-reviewer` 等专项 reviewer 找隐患
5. 派 `everything-claude-code:refactor-cleaner` 找死代码并清
6. 派 `everything-claude-code:silent-failure-hunter` 找静默失败
7. 派 deep-research subagent 调研同类产品功能 → 选 1-2 个补
8. 仍找不到 → 列 5-10 个"如有时间该做"清单,subagent 评估优先级,取最高 1 个做

> **绝不允许**:"实在没事做了 sleep 1h" / "主动结案停" / 长睡到时间到 — 这些都视作偷懒,与"严禁长睡偷懒"精神冲突。

#### 自主停判定模板(每组 5 tick 闭环后、计划下一组前自检)

```
1. 读原始 ARGUMENTS, 分轨到 A/B/C/D/E 五档之一

2. 若是 A (客观时间停):
   - 当前时间 < 停止时刻 → 继续找活 (§6), **严禁** 主动停
   - 当前时间 ≥ 停止时刻 → 自主停, 落 final plan + 结案
   - "活快做完了"不构成停止理由

3. 若是 B (客观完成停):
   - 列已完成 tick 的 commit + 修改对照表 (Tick N → 解决了 ARGUMENTS 哪条要求)
   - 全部 N 条 100% 达成 + auditor PASS → 自主停
   - 任一条未达成 (哪怕 Opus 觉得"接近完美") → 继续, **不得自主停**

4. 若是 C (主观授权停):
   - 列对照表
   - 觉得目标达成 + §6 找活无显著产出 → 自主停 (用户明示授权)
   - 觉得还能再迭代一组 → 告知用户"已达成可主动停, 或继续挖", 继续一组再问

5. 若是 D (明示永续):
   - 永不自主停, 仅 §10.1-3 退出

6. 若是 E (模糊态):
   - betterloop-auditor 顺便判 "是否已达暗示完成态"
   - auditor 判 "已达成" + §6 找活无产出 → 允许自主停
   - 否则继续
```

**自主停的退出动作**(仅 B 全达成 / C 用户授权 / E auditor 同意 三种情况):

1. 落最后一份 `docs/progress/loop-plan-组N-final.md` 含 "自主停理由 + 已达成目标对照表 + 累计成果"
2. 给用户一段简短**结案报告** (commit 列表 + 已达成 vs 原 prompt 目标对照 + 后续可选方向)
3. **不调 ScheduleWakeup** → loop 终止
4. 不需要用户再说"停"

#### 启动时的"停止意图"识别 — 主 Opus 必做(分轨告知)

`/betterloop` 启动 (Step 1 进入 Step 2 前) 自检:

```
读 ARGUMENTS → 提取"何时停"语义 → 在第一轮回复(Tick 1 计划组开头)告知用户:
  - A. "侦测到客观时间停: <时刻>。将守到该时刻才停,绝不提前。活完用 §6 找活。"
  - B. "侦测到客观完成停: <列出要求>。逐条达成后才停,未达不得停。"
  - C. "侦测到主观授权停: <原话>。在认为已达成时自主停。"
  - D. "侦测到明示永续: <原话>。仅你明令才停。"
  - E. "未侦测到明示停止条件, 视为模糊态 (倾向持续, auditor 判达成才自主停)"
```

让用户在第一轮就能纠正你的解读, 避免后期误停 / 误续.

否则（§10.1-4 都未触发）永不停息。

---

## Step 3 ▸ 进入第一轮 tick

按 §1 节奏立即开工：

### 情况 A: 当前项目无 `docs/progress/loop-plan-组*.md` 记录
→ 视为 **组 1 Tick 1（计划组）** 开始：
1. 扫项目（`Glob` / `Grep` / `Read` 或 `Agent(subagent_type=code-explorer, model=sonnet)`）
2. 按 §2.2 五种合格模式列 **4 个候选 tick**（每个含技术方案 + 文件清单 + 预估行数 + 命中模式）
3. **强制 dispatch subagent 审查**（§1 给定的 prompt 模板，按 6 问决策流逐项判定）
4. 任一 WEAK → 主 Opus 放大 scope 重审，循环到全 PASS
5. 落盘 `docs/progress/loop-plan-组1.md`
6. ScheduleWakeup 进入 Tick 2

### 情况 B: 已有 `docs/progress/loop-plan-组N.md` 记录
→ 读最新一份，按 N 和当前 Tick 编号继续：
- 若组 N 已完成 5 个 tick → 进入组 N+1 Tick 1 计划组
- 若组 N 还有未完成的执行 tick → 继续执行 + 实测 + commit
- 若当前 Tick 1 计划组未通过 subagent 审查 → 继续重规划

---

## 防偷懒强制句

主 Opus 接到此命令后：

- ❌ 禁止"先答用户、稍后启动 loop"
- ❌ 禁止"先调研需求、确认范围"等借口拖延
- ❌ 禁止只读规则不调 loop skill
- ✅ Step 1 → Step 2 → Step 3 一气呵成
- ✅ 进入 Tick 1 后立即扫项目 + 列任务 + 派 subagent

**用户输 `/betterloop` 即表示授权立刻进入永不停息的自主迭代状态。**
