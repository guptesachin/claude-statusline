#!/bin/bash
# my-usd.sh — summarize Claude Code usage & estimated spend
#
# Reads the per-session logs written by statusline.sh
# (~/.claude/session-logs/*.json) and prints:
#   - all-time and rolling-window estimated spend
#   - a spend-by-model breakdown
#   - your most recent sessions
#
# For token counts rather than dollars, see my-tokens.sh (/my-tokens).
#
# NOTE: cost_usd is Claude Code's *estimate* of API-equivalent cost. On a
# Pro/Max subscription you don't pay this directly; treat it as a usage signal.
#
# Requires: jq
set -euo pipefail

LOG_DIR="$HOME/.claude/session-logs"
command -v jq >/dev/null 2>&1 || { echo "jq is required."; exit 1; }

shopt -s nullglob
LOGS=("$LOG_DIR"/*.json)
if [ ${#LOGS[@]} -eq 0 ]; then
  echo "No session logs yet at $LOG_DIR."
  echo "They start accumulating once statusline.sh has run in a session."
  exit 0
fi

# Current time (epoch seconds). Passed into jq so all math stays in one place.
NOW=$(date +%s)

# ------------------------------------------------------------------ totals ----
echo "=== Claude Code usage summary ==="
jq -rs --argjson now "$NOW" '
  def since($secs): map(select(.updated_at >= ($now - $secs)));
  def usd: "$" + (.*100|round/100|tostring);
  # NOTE: cost is the reliable per-session cumulative metric. The token fields
  # in these logs are point-in-time context snapshots, NOT cumulative usage, so
  # we do not sum them here — run /my-tokens for real cumulative token usage.
  "Sessions logged : \(length)",
  "Last 24 hours   : \(since(86400)   | map(.cost_usd) | add // 0 | usd)",
  "Last 7 days     : \(since(604800)  | map(.cost_usd) | add // 0 | usd)",
  "Last 30 days    : \(since(2592000) | map(.cost_usd) | add // 0 | usd)",
  "All-time (est.) : \(map(.cost_usd) | add | usd)"
' "${LOGS[@]}"

# --------------------------------------------------------------- by model ----
echo
echo "=== Spend by model (all-time, est.) ==="
jq -rs '
  group_by(.model)
  | map({model: .[0].model, sessions: length, cost: (map(.cost_usd)|add)})
  | sort_by(-.cost)[]
  | "\(.cost | .*100|round/100 | tostring | (" "*(9-length)) + .)  \(.sessions | tostring | (" "*(4-length)) + .)  \(.model)"
' "${LOGS[@]}" | { printf "%9s  %4s  %s\n" "USD" "N" "MODEL"; cat; }

# ------------------------------------------------------- recent sessions ----
echo
echo "=== 10 most recent sessions ==="
jq -rs --argjson now "$NOW" '
  sort_by(-.updated_at)[:10][]
  | "\(.cost_usd | .*100|round/100 | tostring | (" "*(8-length)) + .)  \(.context_pct|tostring + "%" | (" "*(4-length)) + .)  \(((($now - .updated_at)/3600) | if . < 0 then 0 else . end | floor))h ago  \(.cwd | split("/") | last)"
' "${LOGS[@]}" | { printf "%8s  %4s  %-9s %s\n" "USD" "CTX" "WHEN" "PROJECT"; cat; }
