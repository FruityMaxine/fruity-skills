# 示例: anti-slacking-auditor FAIL → BLOCKED 报告

下面是 `anti-slacking-auditor` 对一个**偷懒** turn 的样板。主 Claude 声称"已完成功能 X",但实际有 stub / 未升 VERSION / Co-Authored-By 泄漏三类问题。

第一次审 → FAIL (major); 第二次仍同维度 FAIL → 2-strike 升 critical → BLOCKED。

---

## 第 1 次 audit (tick 1)

### Step 0: History
- 历史 ticks: 空
- 2-strike escalations: 无

### Step 1: Facts
- head: `abc1234` ("feat: add user search endpoint")
- file_types: `[*.py, *.md]`
- 用户原话: "把用户搜索 API 加上, 别偷懒, 全做完"

### Step 2-5: Per-Dimension

| Dim | Severity | Status | Evidence |
|---|---|---|---|
| NO_CO_AUTHOR | critical | **FAIL** | commit msg 含 `Co-Authored-By: Claude` |
| NO_BIND_0000 | critical | PASS | diff 无 `0.0.0.0` |
| REPLY_FULL_CHINESE | critical | PASS | 主 Claude 输出全中文 |
| VERSION_BUMP | major | **FAIL** | `VERSION` 未变, diff 有代码改动 |
| DOC_CODE_SYNC | minor | **FAIL** | 新 API path 未加 README |

### Coverage Map
| 用户原子需求 # | 状态 | 证据 |
|---|---|---|
| 1. 加用户搜索 API | 部分 | `search.py:42` 函数体只有 `pass  # TODO impl` |
| 2. 别偷懒, 全做完 | ✗ | TODO 命中, stub 函数, 未升 VERSION |

### Slacking Pattern Hits
- 关键词: `search.py:42` 含 `# TODO impl`
- 空实现: `search.py:41-43` 函数 `search_users` 只有 `pass`
- 隐式偷懒: commit msg 称"add user search endpoint"但实际是 stub

### 关键问题清单
1. **NO_CO_AUTHOR** —— 位置: HEAD commit msg —— 整改: `git commit --amend` 删 `Co-Authored-By` trailer
2. **VERSION_BUMP** —— 位置: `VERSION` —— 整改: bump `1.2.3.4` → `1.3.0.0` (MINOR: 新功能)
3. **search.py:41-43 stub** —— 整改: 实现 `search_users(query)` 真实逻辑, 不许 `pass`
4. **DOC_CODE_SYNC** —— 位置: `README.md` —— 整改: API 路径 `/users/search` 加进 API 段

## Fail Dimensions: [NO_CO_AUTHOR, VERSION_BUMP, DOC_CODE_SYNC, COVERAGE_PARTIAL]
## Critical Blocks: [NO_CO_AUTHOR]
## Final Verdict: BLOCKED [iter 1/∞]

---

主 Claude 接到 BLOCKED:
1. 不计入 3-iter 上限
2. 三档绕过 (FRUITY_NO_AUDIT / [skip-audit] / .skip flag) 对 critical 失效
3. 必须修 NO_CO_AUTHOR 后再派审

---

## 第 2 次 audit (tick 2 · 假设主 Claude 修了 Co-Authored-By 但还没动 stub)

### Step 0: History
- 历史 ticks: 1 条 (tick 1 FAIL/BLOCKED, fail_dims=[NO_CO_AUTHOR, VERSION_BUMP, DOC_CODE_SYNC, COVERAGE_PARTIAL])
- 2-strike escalations: **VERSION_BUMP 进入观察窗** (连续 1 次, 若再 FAIL 自动升 critical)

### Step 2-5: Per-Dimension

| Dim | Severity | Status | Evidence |
|---|---|---|---|
| NO_CO_AUTHOR | critical | PASS | 已 amend 删 trailer |
| VERSION_BUMP | major | **FAIL** | 仍未升号 |
| (rest) | ... | ... | ... |

### Severity 升级
**[ESCALATED: 2-strike]** VERSION_BUMP 连续 2 次 FAIL → 本次自动升 critical → BLOCKED

## Fail Dimensions: [VERSION_BUMP]
## Critical Blocks: [VERSION_BUMP] (由 2-strike 升级)
## Final Verdict: BLOCKED [iter 2/∞]

---

主 Claude 现在必须修 VERSION_BUMP 才能继续。BLOCKED 状态 Stop hook 永拦, 三档绕过失效。
