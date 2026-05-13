#!/usr/bin/env bash
# fruity-skills · PreToolUse(Write|Edit|MultiEdit|Bash) red-line wrapper
# 真正逻辑在 pre-tool-critical-redline.py
exec python3 "$(dirname "$0")/pre-tool-critical-redline.py"
