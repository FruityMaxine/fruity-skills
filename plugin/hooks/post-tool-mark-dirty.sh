#!/usr/bin/env bash
# fruity-skills · PostToolUse hook (matcher: Write|Edit|MultiEdit|Bash) · v0.10.0.0
#
# 行为:
#   - Write/Edit/MultiEdit: 总是写 dirty (会改文件)
#   - Bash: 只读命令白名单不写 dirty; 写入/危险/未知命令写 dirty (保守默认)
#
# 白名单选定原则: 只列**绝对只读**或**只查状态**的命令; 任何可能修改文件/进程/网络的不在内.

set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')

parse() {
  printf '%s' "$INPUT" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
except: print(''); sys.exit(0)
v=d
for k in '$1'.split('.'):
    if isinstance(v,dict): v=v.get(k,'')
    else: v=''; break
print(v if isinstance(v,str) else '')
" 2>/dev/null
}

SESSION_ID=$(parse session_id)
[[ -z "$SESSION_ID" ]] && exit 0

TOOL=$(parse tool_name)
FLAG="/tmp/fruity-audit-${SESSION_ID}.dirty"

# Write/Edit/MultiEdit 总是 dirty
case "$TOOL" in
  Write|Edit|MultiEdit)
    touch "$FLAG"
    exit 0
    ;;
esac

# Bash: 细粒度判断
if [[ "$TOOL" == "Bash" ]]; then
  CMD=$(parse tool_input.command)
  # 去前导空白 + 取首 token
  CMD_TRIMMED=$(echo "$CMD" | sed -E 's/^[[:space:]]+//')
  FIRST=$(echo "$CMD_TRIMMED" | awk '{print $1}')

  case "$FIRST" in
    # 纯只读 / 查询类
    ls|cat|head|tail|grep|egrep|fgrep|find|locate|wc|stat|du|df|free|ps|top|htop|ss|netstat|ip|route|arp|whoami|id|pwd|env|printenv|date|cal|uptime|uname|hostname|hostnamectl|echo|printf|file|which|whereis|type|man|info|history|jq|yq|tree|less|more|sort|uniq|cut|awk|column|expand|nl|tac|rev|basename|dirname|readlink|realpath|md5sum|sha1sum|sha256sum|sha512sum|b2sum|cksum|true|false|test|expr|seq|nproc|getconf|locale|ldd|nm|strings|hexdump|xxd|od|diff|cmp|comm|join|tput|reset|clear|sleep|timeout)
      exit 0
      ;;
    systemctl)
      SUB=$(echo "$CMD_TRIMMED" | awk '{print $2}')
      case "$SUB" in
        status|show|cat|list-units|list-unit-files|list-jobs|list-timers|is-active|is-enabled|is-failed|get-default|is-system-running|help)
          exit 0 ;;
        *)
          touch "$FLAG"; exit 0 ;;
      esac
      ;;
    git)
      SUB=$(echo "$CMD_TRIMMED" | awk '{print $2}')
      case "$SUB" in
        status|log|diff|show|blame|branch|tag|rev-parse|ls-files|ls-remote|describe|reflog|config|remote|fetch|cat-file|symbolic-ref|grep|name-rev|whatchanged|shortlog|verify-commit|verify-tag)
          exit 0 ;;
        *)
          touch "$FLAG"; exit 0 ;;
      esac
      ;;
    docker)
      SUB=$(echo "$CMD_TRIMMED" | awk '{print $2}')
      case "$SUB" in
        ps|images|inspect|logs|stats|top|info|version|history|port|search)
          exit 0 ;;
        *)
          touch "$FLAG"; exit 0 ;;
      esac
      ;;
    ufw)
      SUB=$(echo "$CMD_TRIMMED" | awk '{print $2}')
      case "$SUB" in
        status|show)
          exit 0 ;;
        *)
          touch "$FLAG"; exit 0 ;;
      esac
      ;;
    gh)
      SUB=$(echo "$CMD_TRIMMED" | awk '{print $2}')
      case "$SUB" in
        auth|api|pr|issue|repo|run|workflow|release|search|browse|status)
          # gh 子命令多, 进一步看第三段: list/view/status 是只读
          SUB2=$(echo "$CMD_TRIMMED" | awk '{print $3}')
          case "$SUB2" in
            list|view|status|show|diff|checks)
              exit 0 ;;
            *)
              touch "$FLAG"; exit 0 ;;
          esac
          ;;
        *)
          touch "$FLAG"; exit 0 ;;
      esac
      ;;
    curl|wget)
      # GET 是 only-read; 但 -o / -O / > file 写本地; -X POST/PUT/DELETE 改远端
      if echo "$CMD_TRIMMED" | grep -qE '(\s-o\s|\s-O\b|\s--output\s|\s>\s|\s>>\s|\s-X\s+(POST|PUT|DELETE|PATCH))'; then
        touch "$FLAG"; exit 0
      fi
      exit 0
      ;;
    python3|python|node|bash|sh|zsh|fish|perl|ruby|lua|deno|bun)
      # 解释器 - 能跑任意代码, 保守一律 dirty
      touch "$FLAG"; exit 0
      ;;
    sed|tr)
      # sed/tr 默认输出到 stdout 不改文件; 若 -i 才写文件
      if echo "$CMD_TRIMMED" | grep -qE '(\s-i\b)'; then
        touch "$FLAG"; exit 0
      fi
      exit 0
      ;;
    tee)
      # tee 写文件, 即使是 read-from-stdin
      touch "$FLAG"; exit 0
      ;;
    xargs)
      # xargs 跑子命令, 保守 dirty
      touch "$FLAG"; exit 0
      ;;
    watch)
      # watch 包别的命令, 无法判断 - 保守 dirty
      touch "$FLAG"; exit 0
      ;;
    *)
      # 未知命令一律保守: 写 dirty
      touch "$FLAG"
      exit 0
      ;;
  esac
fi

exit 0
