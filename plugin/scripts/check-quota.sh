#!/usr/bin/env bash
# fruity-skills · check-quota.sh
# 移植自 github.com/FruityMaxine/claude-quotas v1.4.0 src/lib.ts
# 调 Anthropic OAuth usage API 拿 5h / 7d / Opus / Sonnet quota
# 用法: bash plugin/scripts/check-quota.sh [--json|--summary|--fivehour|--sevenday|--sevenday-opus|--sevenday-sonnet|--resets-in]
# 退出码: 0 成功; 2 credentials 不存在; 3 token 缺失; 4 API 调用失败

set -uo pipefail

MODE="${1:---summary}"
CRED_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json"
USAGE_API="https://api.anthropic.com/api/oauth/usage"
USER_AGENT="fruity-skills-check-quota/0.13.0.0"

if [[ ! -f "$CRED_FILE" ]]; then
  echo "{\"error\":\"credentials not found\",\"path\":\"$CRED_FILE\"}"
  exit 2
fi

TOKEN=$(jq -r '.claudeAiOauth.accessToken // empty' "$CRED_FILE" 2>/dev/null)
if [[ -z "$TOKEN" ]]; then
  echo '{"error":"OAuth accessToken missing"}'
  exit 3
fi

# 调 Anthropic OAuth usage API
RESPONSE=$(curl -sS --max-time 8 \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "User-Agent: $USER_AGENT" \
  -H "anthropic-beta: oauth-2025-04-20" \
  "$USAGE_API" 2>&1)

# 验证 JSON 合法
if ! echo "$RESPONSE" | jq -e . > /dev/null 2>&1; then
  printf '{"error":"API call failed","raw":%s}\n' "$(printf '%s' "$RESPONSE" | jq -Rs .)"
  exit 4
fi

# 取 rate_limit_tier (从 credentials 补充, API 不一定返回)
TIER=$(jq -r '.claudeAiOauth.rateLimitTier // "unknown"' "$CRED_FILE" 2>/dev/null)
SUB_TYPE=$(jq -r '.claudeAiOauth.subscriptionType // "unknown"' "$CRED_FILE" 2>/dev/null)

# 用 jq 加上 subscription_type / rate_limit_tier 到响应顶层
ENRICHED=$(echo "$RESPONSE" | jq --arg t "$TIER" --arg s "$SUB_TYPE" '. + {rate_limit_tier: $t, subscription_type: $s}')

case "$MODE" in
  --json)
    echo "$ENRICHED"
    ;;
  --summary)
    echo "$ENRICHED" | jq -r '
      def reset_in(iso):
        if iso == null or iso == "" then "unknown"
        else
          ((iso | sub("\\.[0-9]+";"") | sub("\\+00:00$";"Z") | fromdateiso8601) - now) as $secs |
          if $secs <= 0 then "resetting now"
          elif $secs < 60 then "<1m"
          else
            ($secs / 60 | floor) as $m |
            if $m >= 1440 then
              ($m / 1440 | floor | tostring) + "d " + (($m % 1440) / 60 | floor | tostring) + "h"
            elif $m >= 60 then
              ($m / 60 | floor | tostring) + "h " + ($m % 60 | tostring) + "m"
            else
              ($m | tostring) + "m"
            end
          end
        end;
      [
        if .five_hour then "5-hour session: \(.five_hour.utilization)% used | resets in " + reset_in(.five_hour.resets_at) else empty end,
        if .seven_day then "7-day weekly:   \(.seven_day.utilization)% used | resets in " + reset_in(.seven_day.resets_at) else empty end,
        if (.seven_day_opus // null) and (.seven_day_opus.resets_at // null) then "7-day Opus:     \(.seven_day_opus.utilization)% used | resets in " + reset_in(.seven_day_opus.resets_at) else empty end,
        if (.seven_day_sonnet // null) and (.seven_day_sonnet.resets_at // null) then "7-day Sonnet:   \(.seven_day_sonnet.utilization)% used | resets in " + reset_in(.seven_day_sonnet.resets_at) else empty end,
        "Plan:           " + (.subscription_type // "unknown")
      ] | join("\n")
    '
    ;;
  --fivehour)
    echo "$ENRICHED" | jq -r '.five_hour.utilization // 0'
    ;;
  --sevenday)
    echo "$ENRICHED" | jq -r '.seven_day.utilization // 0'
    ;;
  --sevenday-opus)
    echo "$ENRICHED" | jq -r '.seven_day_opus.utilization // "null"'
    ;;
  --sevenday-sonnet)
    echo "$ENRICHED" | jq -r '.seven_day_sonnet.utilization // 0'
    ;;
  --resets-in)
    echo "$ENRICHED" | jq -r '
      {
        fh_util: (.five_hour.utilization // 0),
        sd_util: (.seven_day.utilization // 0),
        fh_resets_at: (.five_hour.resets_at // ""),
        sd_resets_at: (.seven_day.resets_at // "")
      }
    '
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    echo "Usage: $0 [--json|--summary|--fivehour|--sevenday|--sevenday-opus|--sevenday-sonnet|--resets-in]" >&2
    exit 1
    ;;
esac
