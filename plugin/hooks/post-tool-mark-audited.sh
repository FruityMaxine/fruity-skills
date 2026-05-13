#!/usr/bin/env bash
# fruity-skills · PostToolUse(Task) hook wrapper · v0.3.0.0
# 实际逻辑在 post-tool-mark-audited.py (避免 heredoc-stdin 冲突)
exec python3 "$(dirname "$0")/post-tool-mark-audited.py"
