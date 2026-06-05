---
description: 从当前 session 总结教训/偏好/操作步骤/TIL,主 Opus 直接做(不派 background Haiku),默认 dry-run + 用户拍板,沿用既有 ~/.claude/projects/-srv-agent-workspace/memory/ 结构。子命令:list/search/retire/promote。
---

# /fruity-learn — 从当前 session 抽教训(主 Opus 直接做)

收到此命令立即按以下协议执行,**不派 background subagent,不调 Haiku,不写 ECC homunculus 目录**。直接在当前 Opus context 内完成全流程。

## 设计原则(写死,不允许偏离)

1. **手动触发 + 重质量,不重数量**: 宁可少存高价值条目,绝不为凑数误存(误存的 lesson 比无更糟)
2. **沿用 user 既有 memory 系统**: 路径 `/root/.claude/projects/-srv-agent-workspace/memory/`,type 用现有 `feedback | reference | project`,**不引入新 type**,**不新建 `~/.claude/lessons/` 第三目录**
3. **默认 dry-run**: 列候选 + verdict 提议 → 等 user 拍板 → 再写盘
4. **5 verdict**: Save / Update / Defer / Ask / Drop
5. **按"召回时机"切类(非"事后是什么")**: 4 类 pitfall / playbook / preference / gotcha
6. **删 decision 类**: 项目内决定属 `<project>/docs/decisions/ADR-*.md`,不进 memory

## 子命令路由(第一行参数判断)

| 输入 | 路径 |
|---|---|
| `/fruity-learn` 或 `/fruity-learn extract` | 默认主流程: 扫 session 抽候选 |
| `/fruity-learn list [type]` | 列出现有 memory 索引,可选过滤 type |
| `/fruity-learn search <keyword>` | grep MEMORY.md + 全文 grep 各 md 找匹配 |
| `/fruity-learn retire <name>` | 把已不再有效的条目标 deprecated + 移到 `.archive/` |
| `/fruity-learn promote <name>` | 项目级 memory → 全局 memory 升级 |
| `/fruity-learn doctor` | 自检 schema 一致性 + 旧条目 + 重复/矛盾 |

下面以**默认主流程 (extract)** 为主写。其他子命令在末尾简述。

---

## Step 0 ▸ schema 一致性自检(首跑必做)

先核对 user 既有 memory 系统的两个隐性债:

```bash
# 检查既有 12 条 memory 用的 type 字段
grep -rE "^type:" /root/.claude/projects/-srv-agent-workspace/memory/*.md 2>/dev/null | sort | uniq -c
```

**预期产出**: `type: feedback / reference / project` 三种。

**若发现新增的不一致类型**(比如某次 better-memory skill 写入了 `type: about_me|rules`):
- **不强行迁移**(沉没成本太大)
- **告知 user**: "侦测到 memory 系统有 N 种 type 字段混用 (feedback/reference/project + ...). 是否在本次结束后跑 `/fruity-learn doctor` 看一下?"
- **本次 extract 沿用 user 老 type 系统**,不引入新 type

---

## Step 1 ▸ 扫 session 触发关键词起步(降低空白起步成本)

**不要让自己从零自由发挥**。先 grep 本 session 转录里 user 的触发关键词,以这些 user 发言为起点抽 lesson 候选。

触发关键词清单(按优先级):

| 关键词 | 对应类型 |
|---|---|
| "记住" / "记下" / "save this" | 任意类(用户主动声明要存) |
| "以后" / "下次" / "from now on" | preference |
| "别" / "不要" / "禁止" / "踩坑" / "翻车" | pitfall |
| "真根因" / "卡了 N 天" / "终于找到" / "原来是" | pitfall (含修复要点) |
| "X 步" / "流程" / "标准动作" / "playbook" | playbook |
| "原来" / "DuckDNS 支持" / "我之前以为" / "TIL" | gotcha |
| "用 X 不用 Y" | preference |

扫完后,**每条 user 触发发言**对应 0-1 个 lesson 候选。如果 user 没说任何触发词,**不自由发挥**,直接告知:

> "本 session 扫到 0 处 user 触发发言,建议 user 手动指认要总结的点 (或本次跳过)。"

---

## Step 2 ▸ 按 4 类候选,各列 trigger + core + evidence

对每个候选,填充以下结构(草稿,不写盘):

```yaml
type_internal: pitfall | playbook | preference | gotcha
context: domain=<topic>          # 召回时机标签, e.g. "domain=systemd-units"
core: <一句话核心, ≤30 字>
evidence: <YYYY-MM-DDTHH:MM> user said "<≤50 字关键引语>"
reuse_score: 0.0-1.0             # 跨项目通用度: 0.3 单项目专有, 0.7 同类项目, 1.0 全局规则
dedup_check: <grep MEMORY.md 既有条目, 标 [新增 | 与 X 重叠 | 与 Y 矛盾]>
proposed_verdict: Save | Update | Defer | Ask | Drop
proposed_path: <写盘路径>
```

### 类型 → user 既有 type 字段映射

| 内部类型 | user 既有 type | 文件名前缀 |
|---|---|---|
| pitfall (踩坑警示) | `feedback` | `feedback_avoid_<topic>.md` |
| playbook (操作步骤) | `reference` | `reference_<topic>_flow.md` |
| preference (偏好) | `feedback` | `feedback_<topic>.md` |
| gotcha (TIL/事实) | `reference` | `reference_<topic>.md` |

### context: domain=X 规则(替代 ECC 的 trigger)

不写 "trigger: when X" 召回字符串(那是 ECC background 注入风格)。用 `context: domain=<topic>` **主题归属标签**:

```yaml
context: domain=systemd-units             # 任何写 systemd unit 时这条相关
context: domain=duckdns-dns                # 配 DuckDNS 时
context: domain=playwright-headless        # Playwright 无头跑时
context: domain=anthropic-billing-policy   # 涉及 Anthropic 计费 / Agent SDK 时
```

---

## Step 3 ▸ 冲突 + 重复检测

对每个候选,执行 2 次检查:

1. **重复检测**: `grep -i "<core 关键字>" /root/.claude/projects/-srv-agent-workspace/memory/MEMORY.md`
   - 命中相同主题 → verdict 改 `Update` (patch 已有 md), 标明 patch 内容
   - 命中类似但角度不同 → verdict 保 `Save`, 但 description 里标 "see also: X"
2. **矛盾检测**: 读完整命中的 md,判断新 lesson 与已存内容**是否互斥**
   - e.g. 已存 "用 systemd 不用 docker", 新 lesson "改用 docker" → verdict 改 `Ask`, 明示矛盾要 user 决定保留哪个
   - **绝不允许新 lesson 静默覆盖已有 lesson**

---

## Step 4 ▸ 5 verdict 决策

按以下规则给每候选下 verdict:

| Verdict | 条件 | 动作 |
|---|---|---|
| **Save** | reuse_score ≥ 0.5 + 无重叠 + 无矛盾 + user 触发明确 | 落新 md + 加 MEMORY.md 索引 |
| **Update** | 重复检测命中相同主题 | patch 已有 md (在 ## 历史 段加新观察, **不覆盖原文**) |
| **Defer** | reuse_score 0.3-0.5 + 不确定是否一次性 | 写到 `<memory>/.staging/` 子目录,不进 INDEX,下次再次出现同主题时升正式 |
| **Ask** | 矛盾 / reuse_score < 0.3 / user 触发模糊 | 列给 user 拍板,**不写盘** |
| **Drop** | trivial / one-off / 已被全局 CLAUDE.md 覆盖 | 不写盘,explain 理由 |

**保守起步**: 边缘 case 一律 `Ask`,不要"我觉得应该 Save"自动写盘。user 显式说"这个记下"才升 Save。

---

## Step 5 ▸ Dry-run 报告(默认行为,等 user 拍板)

按以下模板输出报告,**不写任何文件**:

```
# /fruity-learn 候选清单 (dry-run)

## 扫到 N 处 user 触发发言,提取 M 个候选

### 候选 1: <core 一句话>
- 类型: pitfall (写 feedback_*.md)
- domain: systemd-units
- evidence: 2026-05-29T09:54 user said "systemd unit 不准行尾中文注释"
- reuse_score: 1.0 (全局规则)
- dedup_check: [新增] grep MEMORY.md 无命中
- 矛盾检测: 无
- proposed_verdict: **Save**
- 拟写路径: `~/.claude/projects/-srv-agent-workspace/memory/feedback_avoid_systemd_inline_comment.md`
- 拟加 INDEX 一行: `- [systemd unit 禁行尾中文注释](feedback_avoid_systemd_inline_comment.md) — 整行被吞,资源限制失效`

### 候选 2: ...

### 候选 3: ...

## 综合建议

- Save: 候选 1, 3
- Update: 候选 4 (与 feedback_loop_permanence.md 重叠,patch)
- Defer: 候选 5 (一次性观察待 confirm)
- Ask: 候选 2 (与已有偏好矛盾)
- Drop: 候选 6 (全局 CLAUDE.md 已覆盖)

## 等 user 拍板

请输入: "1,3 save / 2 ask 选 A / 4 update / 5 defer / 6 drop" 等格式
或全部接受: "all"
或全部丢弃: "none"
或具体调整: "候选 3 改 verdict 为 Drop"
```

---

## Step 6 ▸ 应 user 指令写盘

仅在 user 明示后写盘。写盘步骤:

1. **Save**:
   - 写新 md 到 memory 目录
   - frontmatter 含 `name / description / type (user 既有体系) / context / confidence / last_relevant_check`
   - body 含 `## 核心 / ## Why / ## How to apply / ## Evidence (timestamp + 关键引语)`
   - 加 INDEX 一行到 MEMORY.md (保持 ~150 字符以内)
2. **Update**:
   - 在已有 md 的 `## 历史观察` 段(若无则新建段)追加新一条 evidence
   - **不修改原 ## 核心**
   - 更新 frontmatter 的 `last_relevant_check`
3. **Defer**:
   - 写到 `<memory>/.staging/<name>.md`
   - 不动 INDEX
   - frontmatter 标 `confidence: 0.4 status: staging`
4. **Ask**:
   - 等待 user 后续指令,不动盘
5. **Drop**:
   - 不动盘,记录理由到本次回复

最后回报: "已 save N 条 / patch M 条 / defer K 条 / ask J 条等用户后续 / drop L 条"。

---

## 写盘模板 (Save 类)

frontmatter:

```markdown
---
name: <kebab-case-name>
description: <120 字符内,用于召回判断>
type: feedback | reference | project
context: domain=<topic>
confidence: 0.7-1.0
last_relevant_check: 2026-05-29
evidence: <ISO-timestamp> user said "<≤50 字关键引语>"
---
```

body:

```markdown
## 核心

<一句话陈述, 与 description 一致>

## Why

<为什么这条值得记 — 背景/动机/教训出处>

## How to apply

<未来场景下应该怎么做 — 触发情况 + 动作 + 反例>

## Evidence

- <timestamp> user said: "<完整引语>"
- (可选) git commit <hash>: <brief>
- (可选) 相关 session: <topic>
```

---

## INDEX 更新模板

`MEMORY.md` 加一行,保持现有风格:

```markdown
- [<人类可读标题>](<filename>.md) — <≤80 字一句话钩子>
```

---

## 子命令简述

### `/fruity-learn list [type]`

不动盘,只读输出:

```bash
ls /root/.claude/projects/-srv-agent-workspace/memory/*.md | head -50
# 按 type 过滤时:
grep -lE "^type: (feedback|reference|project)" *.md
```

输出格式: 表格 (name / type / context / last_relevant_check / 一句话 description)。

### `/fruity-learn search <keyword>`

```bash
# 索引层 grep
grep -i "<keyword>" /root/.claude/projects/-srv-agent-workspace/memory/MEMORY.md
# 全文层 grep
grep -irE "<keyword>" /root/.claude/projects/-srv-agent-workspace/memory/*.md
```

输出: 命中文件 + 高亮行,问 user 是否要 Read 完整文件。

### `/fruity-learn retire <name>`

```bash
# 1. 加 frontmatter status: deprecated + deprecated_at
# 2. mv 到 .archive/ 子目录
# 3. 从 MEMORY.md INDEX 移除
# 4. 在 MEMORY.md 末尾的 "## Archived" 段加一行 (保留可追溯性)
```

需 user 确认 `<name>` 拼写正确。

### `/fruity-learn promote <name>`

把项目级 memory 升到全局(若 user 决定建立 `~/.claude/memory/` 全局目录):

```bash
mv <project>/memory/<name>.md ~/.claude/memory/<name>.md
# 更新两边 INDEX
# 加一行 "promoted: <date> from <project>" 到 frontmatter
```

**注**: 当前 user 系统是项目级当全局用,此命令暂时无差异。先实现框架,user 决定真用时再激活。

### `/fruity-learn doctor`

自检 + 报告:

1. **schema 一致性**: 统计现有 type 字段分布,标出与 user 主流(feedback/reference/project)不一致的条目
2. **last_relevant_check 过期**: 列出 6 个月以上没 touch 的条目,问 user 是否 retire
3. **INDEX vs 文件一致性**: MEMORY.md 索引有的 md 文件实际不存在 / 反之
4. **重复 + 矛盾扫**: 跨条目找语义相近或互斥
5. **frontmatter 完整性**: 缺必需字段的条目

输出: 报告 + 修复建议,**不自动改**,等 user 拍板。

---

## 反偷懒红线(给主 Opus 自己看)

执行 /fruity-learn 时不允许:

- ❌ 没扫 user 触发关键词就开始"自由发挥"抽 lesson(必走 Step 1)
- ❌ 把 architect 决定 / project ADR 性内容塞 memory(归 `<project>/docs/decisions/`)
- ❌ 引入新 type 字段(只用 feedback / reference / project)
- ❌ 新建 `~/.claude/lessons/` 目录(用既有 memory 路径)
- ❌ 跳过 dedup + 矛盾检测直接写盘
- ❌ verdict 默认 Save(必须保守,边缘 case Ask)
- ❌ 一次跑就强行写盘(必走 dry-run 报告 + user 拍板,除非 user 跑时加 `--commit` 参数)

## 进阶用法(可选参数)

| 参数 | 效果 |
|---|---|
| `/fruity-learn --commit` | 跳过 dry-run,按提议 verdict 直接写(慎用) |
| `/fruity-learn --keywords "X,Y,Z"` | 限定本次只扫这些关键词,不用默认清单 |
| `/fruity-learn --type pitfall` | 只抽 pitfall 类,忽略其他 |
| `/fruity-learn --since "2 hours ago"` | 只扫指定时间窗内 user 发言 |

---

## 与 ECC continuous-learning-v2 / better-memory 的关系

| 系统 | 触发 | 写哪 | 给谁读 |
|---|---|---|---|
| ECC observer-loop (`claude -p` Haiku) | 自动 background | `~/.claude/homunculus/.../instincts/*.md` | ECC SessionStart 注入 |
| ECC `/learn-eval` | 手动 | `~/.claude/skills/learned/` | 手动 grep |
| better-memory skill | 手动(意图驱动) | `~/.claude/memory/` (理论) | 全局 CLAUDE.md 自动注入 |
| **本 /fruity-learn** | **手动 slash** | **`~/.claude/projects/-srv-agent-workspace/memory/`** | **全局 CLAUDE.md 已自动注入 MEMORY.md 索引** |

**不冲突**: 本 command 写 user 既有 memory 系统,不动 ECC homunculus,不动 better-memory 路径。三套并存但**只有本 memory 系统会真被读**(全局 CLAUDE.md 加载)。

**user 后续若想统一**: 跑 `/fruity-learn doctor` 报告不一致,然后按建议手动 migrate(不在本 command 自动范围内,避免破坏已存内容)。
