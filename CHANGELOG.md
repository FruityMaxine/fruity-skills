# Changelog

遵 SemVer 4 段制 `MAJOR.MINOR.PATCH.BUILD`。


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
