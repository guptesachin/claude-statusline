#!/bin/bash
# my-tokens.sh — summarize Claude Code token usage across all sessions
#
# Reads the session transcripts at ~/.claude/projects/**/*.jsonl and prints:
#   - rolling-window and all-time token totals
#   - a tokens-by-model breakdown (input / output / cache write / cache read)
#   - your most recent sessions by token volume
#
# This is the companion to my-usd.sh: that one owns dollars, this one owns
# tokens. They read different data sources on purpose — the per-session logs
# my-usd.sh reads only carry point-in-time *context window* snapshots, which
# are not cumulative and cannot be summed. True usage lives in the transcripts.
#
# Three things this script has to get right, all verified against real data:
#   1. Dedup on requestId. Claude Code writes one JSONL record per content
#      block, so a thinking+text+tool_use response is three records sharing one
#      identical usage object. Summing naively inflates totals ~2.15x.
#   2. Find, not globs. Transcripts nest three levels deep in three different
#      shapes (session, subagents/, subagents/workflows/wf_*/); a fixed-depth
#      glob silently misses the last one.
#   3. Skip <synthetic> records — local API-error placeholders with zero usage.
#
# Requires: jq
set -euo pipefail

PROJECTS="$HOME/.claude/projects"
command -v jq >/dev/null 2>&1 || { echo "jq is required."; exit 1; }
[ -d "$PROJECTS" ] || { echo "No transcripts found at $PROJECTS."; exit 0; }

# Current time (epoch seconds), passed into awk so all the window math is in
# one place.
NOW=$(date +%s)

# jq flattens each assistant record to a TSV row; awk dedups and aggregates.
# /dev/null is passed as a guaranteed input file: GNU xargs runs its command
# even on empty input, and a jq with no file arguments would sit reading stdin.
# `|| true` keeps one corrupt transcript line from failing the whole report
# under `set -o pipefail` — jq skips the bad line and we still print the rest.
{ find "$PROJECTS" -name '*.jsonl' -print0 | xargs -0 jq -r '
  select(.type=="assistant" and (.message.usage|type)=="object")
  | select((.message.model // "") != "<synthetic>")
  | [ (.requestId // .message.id // "?"),
      ((.timestamp // "1970-01-01T00:00:00Z") | sub("\\.[0-9]+Z$";"Z") | fromdateiso8601),
      (.message.model // "unknown"),
      (.message.usage.input_tokens // 0),
      (.message.usage.output_tokens // 0),
      (.message.usage.cache_creation_input_tokens // 0),
      (.message.usage.cache_read_input_tokens // 0),
      (.sessionId // "?"),
      ((.cwd // "?") | split("/") | last)
    ] | @tsv' /dev/null 2>/dev/null || true; } \
| awk -F'\t' -v now="$NOW" '
# Format a raw token count as 1.71B / 532.35M / 4.78k. Token counts run to
# billions, so every number in this report goes through here — do not pad
# these by hand the way my-usd.sh does, it breaks once a value outgrows its
# column.
function h(n,  u,i) { split(",k,M,B,T", u, ",")
  i=1; while (n >= 1000 && i < 5) { n/=1000; i++ }
  return (i==1) ? sprintf("%d", n) : sprintf("%.2f%s", n, u[i]) }

# seen[] is the dedup gate: first record of a requestId wins, the rest are
# repeats of the same API response and must not be counted again.
!seen[$1]++ {
  t=$2; m=$3; iin=$4; out=$5; cw=$6; cr=$7; sid=$8; proj=$9
  tot=iin+out+cw+cr; age=now-t
  if (age<=86400)   T24+=tot
  if (age<=604800)  { T7+=tot; CW7+=cw; CR7+=cr }
  if (age<=2592000) T30+=tot
  ALL+=tot; IN+=iin; OUT+=out; CW+=cw; CR+=cr
  M[m]+=tot; MR[m]++; MI[m]+=iin; MO[m]+=out; MW[m]+=cw; MC[m]+=cr
  # Records inside subagents/ carry the parent sessionId, so subagent tokens
  # roll up into their session for free.
  S[sid]+=tot; if (t>ST[sid]) ST[sid]=t; SP[sid]=proj
  n++
}

END {
  if (n == 0) { print "No token usage found in transcripts."; exit }

  printf "=== Claude Code token usage ===\n"
  printf "Requests logged : %d\n", n
  printf "Sessions        : %d\n", length(S)
  printf "Last 24 hours   : %s\n", h(T24)
  printf "Last 7 days     : %s\n", h(T7)
  printf "Last 30 days    : %s\n", h(T30)
  printf "All-time        : %s\n", h(ALL)
  printf "Token split     : %s in / %s out / %s cache-w / %s cache-r\n", h(IN), h(OUT), h(CW), h(CR)
  # --- derived efficiency metric ------------------------------------------
  # Cache reuse: how many times the average cached token got read back. This
  # is deliberately NOT a hit-rate percentage — reads so dominate writes that
  # every percentage formulation pins at 97-98% and never moves. The ratio has
  # real spread (34x all-time vs 51x over a busy week), so it can actually tell
  # a good week from a bad one. Higher = context is being amortized further.
  if (CW > 0) {
    line = sprintf("Cache reuse     : %.1fx all-time", CR/CW)
    if (CW7 > 0) line = line sprintf(", %.1fx last 7d", CR7/CW7)
    print line
  }

  printf "\n=== Tokens by model (all-time) ===\n"
  printf "%9s %6s %9s %9s %9s %10s  %s\n","TOTAL","REQS","IN","OUT","CACHE_W","CACHE_R","MODEL"
  # Sort on a hidden raw-number first field, then cut it away. Sorting the
  # formatted column with `sort -h` is unreliable across BSD and GNU.
  srt="sort -t\"\t\" -k1,1rn | cut -f2-"
  for (m in M) printf "%d\t%9s %6d %9s %9s %9s %10s  %s\n", M[m], h(M[m]), MR[m], h(MI[m]), h(MO[m]), h(MW[m]), h(MC[m]), m | srt
  close(srt)

  printf "\n=== 10 most recent sessions ===\n"
  printf "%9s  %-8s %s\n","TOTAL","WHEN","PROJECT"
  srt2="sort -t\"\t\" -k1,1rn | head -10 | cut -f2-"
  for (s in S) { a=int((now-ST[s])/3600); if (a<0) a=0
    printf "%d\t%9s  %-8s %s\n", ST[s], h(S[s]), a "h ago", SP[s] | srt2 }
  close(srt2)
}'
