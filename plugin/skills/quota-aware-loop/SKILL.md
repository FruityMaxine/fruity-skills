---
name: quota-aware-loop
description: Use when running /loop dynamic mode, before any ScheduleWakeup, before starting a long autonomous task (10+ tool calls expected), or every ~5 tool calls during long work. Reads claude-quotas MCP check_quota and decides pacing (delaySeconds, scope) based on 5h/7-day utilization. Requires claude-quotas plugin installed.
---

# quota-aware-loop

让 Claude 自己看自己的配额, 在 /loop / ScheduleWakeup / 长任务前主动节制。

## 前置依赖

**必装**: `claude-quotas` plugin (提供 `mcp__plugin_claude-quotas_claude-quotas__check_quota` MCP tool)

```bash
claude plugin marketplace add https://github.com/FruityMaxine/claude-quotas.git
claude plugin install claude-quotas@claude-quotas
```

## 触发场景 (按重要性排序)

| 场景 | 必查 | 备注 |
|---|---|---|
| **/loop dynamic mode 进入时** | ✅ 强制 | 决定下次 ScheduleWakeup 的 delaySeconds |
| **每次 ScheduleWakeup 前** | ✅ 强制 | 同上 |
| **长任务开始前** (预计 10+ tool calls) | ✅ 强制 | 决定是否 break + ScheduleWakeup |
| **大改动前** (改 5+ 文件 / 部署 / 跨服务) | ⚠️ 推荐 | 评估能否一次做完 |
| **autonomous loop 每 5 个 tool call** | ⚠️ 推荐 | 中途监控 |
| **普通 turn** | ❌ 跳过 | 浪费 token |

## 调用方法

```
mcp__plugin_claude-quotas_claude-quotas__check_quota()
```

返回 JSON:
```json
{
  "five_hour":   {"utilization": 88, "resets_at": "2026-05-13T08:50:00Z"},
  "seven_day":   {"utilization": 92, "resets_at": "2026-05-14T12:00:00Z"},
  "seven_day_sonnet": {"utilization": 0,  "resets_at": "..."},
  "subscription_type": "max",
  "summary": "5-hour session: 88% used | resets in 33m\n..."
}
```

## 决策表 — pacing 行为

### 五小时窗口决策

| 5h util | 7d util | ScheduleWakeup delaySeconds | 主 Claude 行为 |
|---|---|---|---|
| < 50% | < 70% | **270s** (cache warm) | 放手做 |
| 50-80% | < 70% | **270s** | 保持节奏 |
| 80-90% | < 85% | **跳到 5h 重置 + 5min 缓冲**: `min(3600, fh_reset_secs+300)` | 收尾不开新任务 |
| 90-95% | < 85% | **跳到 5h 重置**: `min(3600, fh_reset_secs)` | **强制 ScheduleWakeup + omit work** |
| > 95% | any | **跳到 5h 重置 + 立即停** | **立刻停, 不再 tool call** |

### 七天窗口决策 — 优先级高

| 7d util | 处置 |
|---|---|
| < 70% | 正常 |
| 70-85% | **慎做大任务** (改 5+ 文件 / 跨服务) |
| 85-90% | **vigilance 阈值** — graceful wrap-up 当前任务, 不开新任务 |
| 90-95% | **immediate stop** — ScheduleWakeup 跳到 weekly 重置 (≤ 3600s 分多次) |
| > 95% | **emergency stop** — TaskStop 所有 monitor, omit ScheduleWakeup, 通知用户 |

**7d 优先级 > 5h**: 7d 用完一周不能恢复, 5h 用完 5 小时后能恢复。

## ScheduleWakeup delaySeconds 计算 (伪代码)

```python
quota = check_quota()
fh_pct = quota.five_hour.utilization
sd_pct = quota.seven_day.utilization
fh_reset_in = (parse(quota.five_hour.resets_at) - now).total_seconds()
sd_reset_in = (parse(quota.seven_day.resets_at) - now).total_seconds()

# 7d emergency: 跳到 weekly 重置 (会分多次因 max 3600)
if sd_pct >= 95:
    return min(3600, sd_reset_in)

# 7d vigilance: 跳到 weekly 重置
if sd_pct >= 90:
    return min(3600, sd_reset_in)

# 5h emergency: 跳到 5h 重置
if fh_pct >= 95:
    return min(3600, fh_reset_in)

# 5h vigilance: 跳到 5h 重置 + 缓冲
if fh_pct >= 85:
    return min(3600, fh_reset_in + 300)

# 正常: 短 cache warm
return 270
```

## 与 /loop dynamic 集成

`/loop` skill 在 ScheduleWakeup step 3 之前**必须**:

```
1. 调 check_quota
2. 用上述决策表算 delaySeconds
3. 把这个值写进 ScheduleWakeup.delaySeconds 字段
4. 在 reason 字段写 "quota-aware: 5h=X% 7d=Y%, 跳 Z 秒"
```

## 与 anti-slacking-auditor 联动

- weekly > 85% → auditor 可酌情放宽 minor 维度 (避免反复审烧 token)
- weekly > 90% → Stop hook 收到 reason 提示 "weekly 高水位, 已 schedule sleep"
- 配置: 用 `FRUITY_QUOTA_AWARE=1` env var 启用 (默认 off, 避免破坏既有审查严格度)

## 红线

- **永远不基于 quota 状态绕过 critical 红线**: secrets/Co-Authored-By/bind 0.0.0.0 这些不能因"快烧爆了就跳过"
- **不轮询 quota 太频繁**: 每 5 个 tool call / 关键节点查一次足够; 每个 tool call 都查 = 烧 token

## 用户原话明示场景

场景 1: "5 小时内匀速消耗到 90-95% 后跳 5h 继续"
→ 用 5h 决策表的 90-95% 行: `min(3600, fh_reset_in)`, 多轮叠加跳到 5h 重置

场景 2: "非 loop 单任务, 任务长但额度不剩"
→ 任务开始前 check_quota; 若 7d > 85% 警告用户考虑改日做或拆分

## 触发提示词

主 Claude 看到以下 prompt 关键词时应主动 check_quota:
- "继续 loop" / "继续做"
- "/loop" 命令
- "schedule" / "ScheduleWakeup"
- "继续做事" / "再做一轮"
- 任务描述含"全部 / 一口气 / 跑完 / 一直做"

## 与 better-memory 互操作

- 可把"今日额度耗尽节点"作为 about_me 记忆 (low priority)
- 可把"每日 quota 余裕节点"作为 reference (用于规划)
- 不强制记录, 用户主动要求时存

## token 经济

- skill 描述加载 (UserPromptSubmit 时) ≈ 30 token (永久)
- check_quota MCP 调用 ≈ 100 input + 400 output = ~500 token/次
- 在 ScheduleWakeup / 长任务前调用 (~5-10 次/天) → 每天 ~3000 token
- ROI: 防 weekly 烧爆需周末手动等 = 价值 >> 3000 token
