#!/bin/bash
# Claude Code Status Line
# Shows: model | tokens (%) | cost | running sessions
#
# Claude Code pipes a JSON object into this script on stdin and renders
# whatever it prints on stdout as the status line.
#
# Requires: jq  (https://jqlang.github.io/jq/)

DATA=$(cat)

# --- Extract fields via jq ---------------------------------------------------
MODEL=$(echo "$DATA" | jq -r '.model.display_name // "N/A"')
CTX_PCT=$(echo "$DATA" | jq -r '.context_window.used_percentage // 0')
COST=$(echo "$DATA" | jq -r '.cost.total_cost_usd // 0')

# Used tokens in thousands, total context window in millions
USED_K=$(echo "$DATA" | jq -r '(.context_window.context_window_size // 0) * (.context_window.used_percentage // 0) / 100 / 1000 | floor')
TOTAL_M=$(echo "$DATA" | jq -r '(.context_window.context_window_size // 0) / 1000000')

# --- Log this session's stats for `my-usd.sh` / `/my-usd` --------------------
# One file per session_id, overwritten on each refresh, so each file always
# holds that session's latest cumulative totals (cost, tokens, lines). Summing
# across files = your all-time totals, with no double-counting. Safe to remove
# this block if you only want the status bar and not the spend report.
SESSION_ID=$(echo "$DATA" | jq -r '.session_id // empty')
if [ -n "$SESSION_ID" ]; then
  LOG_DIR="$HOME/.claude/session-logs"
  mkdir -p "$LOG_DIR" 2>/dev/null
  echo "$DATA" | jq -c '{
    model: (.model.display_name // "N/A"),
    model_id: (.model.id // "N/A"),
    context_used_k: ((.context_window.context_window_size // 0) * (.context_window.used_percentage // 0) / 100 / 1000 | floor),
    context_total_m: ((.context_window.context_window_size // 0) / 1000000),
    context_pct: (.context_window.used_percentage // 0),
    cost_usd: (.cost.total_cost_usd // 0),
    duration_ms: (.cost.total_duration_ms // 0),
    lines_added: (.cost.total_lines_added // 0),
    lines_removed: (.cost.total_lines_removed // 0),
    total_input_tokens: (.context_window.total_input_tokens // 0),
    total_output_tokens: (.context_window.total_output_tokens // 0),
    cwd: (.cwd // "N/A"),
    updated_at: now
  }' > "$LOG_DIR/$SESSION_ID.json" 2>/dev/null
fi

# --- Count running Claude Code sessions --------------------------------------
# Claude Code writes one JSON file per session to ~/.claude/sessions/ with a
# `pid` field. `kill -0` tests whether that process is still alive.
RUNNING=0
for f in "$HOME"/.claude/sessions/*.json; do
  [ -f "$f" ] || continue
  pid=$(jq -r '.pid' "$f" 2>/dev/null)
  if kill -0 "$pid" 2>/dev/null; then
    RUNNING=$((RUNNING + 1))
  fi
done

echo "${MODEL} | ${USED_K}k/${TOTAL_M}m tokens (${CTX_PCT}%) | \$${COST} | ${RUNNING} sessions"
