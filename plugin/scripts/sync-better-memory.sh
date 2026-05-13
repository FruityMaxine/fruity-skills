#!/usr/bin/env bash
# fruity-skills · 同步 better-memory 公共版到内置副本
# 用法: bash plugin/scripts/sync-better-memory.sh [--check]
#   --check: 仅检查漂移不写入 (exit 1 = 有漂移)

set -euo pipefail

REPO="https://github.com/FruityMaxine/better-memory.git"
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST_SKILL="$PLUGIN_DIR/skills/better-memory/SKILL.md"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

echo "[sync] cloning $REPO into $TMP ..."
git clone --depth 1 --quiet "$REPO" "$TMP/repo"

SRC_SKILL="$TMP/repo/skills/better-memory/SKILL.md"
if [[ ! -f "$SRC_SKILL" ]]; then
  echo "[sync] FATAL: 公共仓未找到 skills/better-memory/SKILL.md" >&2
  exit 2
fi

SRC_HASH=$(sha256sum "$SRC_SKILL" | cut -d' ' -f1)
DEST_HASH=$(sha256sum "$DEST_SKILL" | cut -d' ' -f1)

if [[ "$SRC_HASH" == "$DEST_HASH" ]]; then
  echo "[sync] up-to-date · hash=$SRC_HASH"
  exit 0
fi

SRC_VER=$(grep -E '"version"' "$TMP/repo/.claude-plugin/plugin.json" 2>/dev/null | head -1 | sed -E 's/.*"version":\s*"([0-9.]+)".*/\1/' || echo "unknown")

if [[ "${1:-}" == "--check" ]]; then
  echo "[sync] DRIFT detected" >&2
  echo "  local  hash: $DEST_HASH" >&2
  echo "  remote hash: $SRC_HASH (v$SRC_VER)" >&2
  exit 1
fi

cp "$SRC_SKILL" "$DEST_SKILL"
echo "[sync] updated: $DEST_SKILL"
echo "[sync] now reflects better-memory v$SRC_VER (hash $SRC_HASH)"
echo ""
echo "下一步: cd $(dirname "$PLUGIN_DIR") && git diff plugin/skills/better-memory/SKILL.md → 升 VERSION → 同步 manifest → commit + push"
