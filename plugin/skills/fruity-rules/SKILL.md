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
