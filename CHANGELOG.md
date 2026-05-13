# Changelog

遵 SemVer 4 段制 `MAJOR.MINOR.PATCH.BUILD`。


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
