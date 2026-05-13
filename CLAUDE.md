# fruity-skills 项目级指令

你正在 fruity-skills 这个 plugin 项目里干活。

## 项目目的

FruityMaxine 的私人 Claude Code 规则集，要能通过 marketplace 分发到他名下的多台设备。**不是给别人用的通用工具，是为他个人定制**。

## 关键约束

1. **作者只有 FruityMaxine**：commit 不带 `Co-Authored-By` trailer
2. **版本号强制 4 段制**：`MAJOR.MINOR.PATCH.BUILD`，每次改动必升 `VERSION` + 同步进 `marketplace.json` / `plugin.json`，写进同一个 commit
3. **目录结构不要乱动**：marketplace.json 在顶层 `.claude-plugin/`；plugin 主体在 `plugin/` 子目录
4. **hook 脚本兼容性**：bash 写，不依赖 node/python 环境，读 `$CLAUDE_PLUGIN_ROOT` 定位 plugin 根

## 校验

```bash
jq . .claude-plugin/marketplace.json
jq . plugin/.claude-plugin/plugin.json
```

## 文档同步

README.md / `marketplace.json` description / `plugin.json` description 三处保持语义一致；description 只写"何时触发"，不写工作流（参 superpowers writing-skills）。
