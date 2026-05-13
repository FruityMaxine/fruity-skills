---
name: fruity-rules
description: Use when working in any project owned by FruityMaxine to apply his cross-device coding rules (4-segment SemVer bump per change, no Co-Authored-By trailers, anti-slacking enforcement, Chinese replies, file paths/SSH/UFW conventions for Vega server). Loads automatically; cite the relevant rule when applying it.
---

# fruity-rules

FruityMaxine 跨设备共享的工作规则速查 —— 不重复全局 CLAUDE.md, 只列**最常违反**的红线。

## Quick Reference

| 红线 | 处置 |
|---|---|
| 任何修改不升 `VERSION` 4 段号 | 同 commit 内必升, 右侧归零 |
| commit 带 `Co-Authored-By` | 立即 `commit --amend` 去掉 |
| 用户列了 N 个需求 (1./2./3.) | 一轮做完, 不准 "下一轮接力" |
| 偷懒话术 (stub / 范本 / 后续可补) | 当 FAIL 信号 |
| 前端 UI 改了未截图 | 跑 Playwright + Read 截图实测 |
| systemd unit 行尾中文注释 | 注释独立成行, 否则整行被静默忽略 |
| 后端服务 bind `0.0.0.0` | 改 `127.0.0.1:<port>`, Caddy 反代 |
| 新 :28xxx 端口未加 UFW | `ufw allow 28xxx/tcp` |
| 子项目用独立账号密码登录 | 走 Homepage token Cookie 守门 |
| 回复出现非中文 (韩日英文段落) | 立即重写 |

## 触发场景

只要 cwd 在 FruityMaxine 名下任意项目 (Vega 服务器: `/srv/agent-workspace/projects/*`, `/opt/polyham`, `/opt/sub2api` 等), 本 skill 适用。

## 与 fruity-skills 其他组件配合

- `[SkillMatch]` 首行声明: 由 UserPromptSubmit hook 强制注入提示, Claude 必须遵守
- 反偷懒审核: Stop hook 派 `anti-slacking-auditor` 自动审, 不用主动调用

## 何时引用本 skill

- 报版本号 / 起 commit / 写 systemd / 配 Caddy / 接 UFW / 部署到 :28xxx 子项目 → 引用对应红线行
- 用户的"立刻 / 全部 / 别偷懒" 触发 → 引用反偷懒红线
- 写代码 / 文档 / 注释 出现非中文段落 → 引用语言红线

## 不适用

- 非 FruityMaxine 的项目 (开源贡献 / 客户代码)
- 公网公开仓库的标准实践 (那时遵原项目惯例)

## 红线详解 (展开 Quick Reference)

### 1. VERSION 4 段升号

**规则**: 任何代码 / 配置 / 文档变动 → 同 commit 内 `VERSION` 文件必升号。

格式 `MAJOR.MINOR.PATCH.BUILD`:

| 段 | 升号时机 |
|---|---|
| MAJOR | 破坏性 API / schema 不兼容 |
| MINOR | 向后兼容的新功能 |
| PATCH | bug 修复 |
| BUILD | 微调 (文档 typo / 注释 / 单字符) |

**右侧归零**: `2.0.0.5` 修 bug → `2.0.1.0` (不是 `2.0.1.5`)
**多类型混合**: 按最大那段升
**不确定时**: 默认 BUILD

manifest 同步: `VERSION` / `marketplace.json:metadata.version` / `marketplace.json:plugins[0].version` / `plugin.json:version` 四处必须一致。

### 2. Co-Authored-By 禁绝

**规则**: commit message / PR body 永不含 `Co-Authored-By` trailer。

**为什么**: 用户独占 GitHub contributor 列表; AI 出现 = 严重错误。

**怎么改**: 触发 → `git commit --amend` 去 trailer → 本地未 push 时直接 amend。

### 3. 偷懒话术黑名单

文档 / commit / 注释 / 代码任何位置含下列任一 → FAIL:

```
中文: 范本 / 首批 / 接力 / 后续可补 / 以后再做 / 待完善 / 占位 / 半成品 / 下一轮 / 暂时
英文: TODO / FIXME / XXX / stub / placeholder / not implemented / skip for now
空实现: pass / return None / throw new Error("not implemented") / {}
```

例外: tests 文件中 placeholder 用于占位测试可接受, 但需在 commit msg 说明。

### 4. 前端 UI 实测铁律

**规则**: 改 `*.tsx`/`*.jsx`/`*.vue`/`*.html`/`*.css` → 提交前必须 Playwright 实测 + 截图证据。

**怎么测** (Vega root 环境):

```bash
.venv/bin/pip install playwright -q
npx -y playwright@latest install chromium
npx -y playwright@latest install-deps chromium
.venv/bin/python -c "
import asyncio
from playwright.async_api import async_playwright
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(headless=True, args=['--no-sandbox','--disable-dev-shm-usage'])
        page = await (await b.new_context(viewport={'width':1280,'height':1100})).new_page()
        await page.goto('http://127.0.0.1:<port>/...')
        await page.wait_for_load_state('networkidle', timeout=15000)
        await page.screenshot(path='/tmp/ui-shot.png', full_page=True)
        await b.close()
asyncio.run(main())
"
```

然后 `Read /tmp/ui-shot.png` 用多模态确认效果。**不允许只看代码就声明 UI 修好。**

### 5. systemd unit 注释陷阱

**规则**: `.service` 文件**禁止行尾注释**。注释必须独立成行。

**陷阱**: systemd 不支持行尾注释, 整行被静默忽略。即:

```ini
MemoryMax=1500M    # 此行被忽略, MemoryMax 不生效
```

**正确**:

```ini
# 内存上限 1.5G
MemoryMax=1500M
```

### 6. 后端服务 bind 规则

**规则**: 任何后端服务必须 bind `127.0.0.1:<port>`, **禁止** bind `0.0.0.0`。

公网入口走 Caddy 反代 (Caddy bind 80/443), 子项目走 :28xxx 端口 + token Cookie 守门。

### 7. :28xxx 端口的 UFW 放行

**规则**: 新增 :28xxx Caddy 端口 → 同 commit / 同部署步骤必有 `ufw allow 28xxx/tcp comment "..."`。

**为什么**: loopback 不经 UFW (盲区), 本机 `curl 127.0.0.1:28xxx` 200 但外网包到不了 Caddy。**必须从公网 IP 实测一次**: `curl http://178.104.190.68:28xxx/healthz`。

### 8. 子项目 token Cookie 守门

**规则**: :28xxx 子项目 WebUI 入口必须有三段守门 (参 PolyHam :28100 / AI Council :28200):

1. 健康检查 path → 放行
2. `?pass=<32 位 hex token>` → `Set-Cookie <proj>_pass=<token>; HttpOnly; SameSite=Lax; Max-Age=86400` + 302 redir 去 query 后同 path
3. `header_regexp Cookie <proj>_pass=<token>` 命中 → reverse_proxy
4. Referer 同源 `^https://vega-hub\.duckdns\.org` → 顺手补 Cookie + reverse_proxy
5. 三关全不命中 → `redir https://vega-hub.duckdns.org/ 302`

Homepage 卡片链接形如 `http://<host>:28xxx/?pass=<token>`, token 写 `/opt/homepage/config/services.yaml` (**不入 git**)。

### 9. 回复必须全中文

**规则**: 给用户的回复 / commit message / 代码注释 / 文档段落主体 → 全简体中文。

例外: 技术术语 (`HTTP`/`TCP`/`Playwright`/`systemd`) / 命令字符串 / 错误信息引用 / 文件路径 / 代码标识符 — 这些保留英文。

**禁出现**: 韩语 / 日语 / 任何非中文段落。出现立即重写。

### 10. 文言文 ACK + Hook 触发的事实陈述

**规则**: ECC GateGuard `fact-forcing` hook 拦截要求陈述 4 项事实 → 用文言文凝练:

```
一、调用方: ...
二、现存文件: ...
三、数据读写: ...
四、用户原话: "..."  ← 保留用户原话不文言化
```

**其他场景**: 给用户的解释 / 进度 / commit message / 代码注释 一律现代白话简体中文, **绝不**扩散文言文风。

## 红线优先级

```
critical (硬循环不绕过)  >>  major (走 3-iter 上限)  >>  minor (累计 ≥2 才 FAIL)
```

由 `anti-slacking-auditor` sub-agent 自动分级判定; PreToolUse `pre-tool-critical-redline` hook 事前拦 critical (Co-Authored-By / bind 0.0.0.0 / secrets / systemd 行尾注释 / rm -rf / mkfs)。
