# Claude Code Status Line

A custom [status line](https://docs.claude.com/en/docs/claude-code/statusline) for Claude Code that shows, at a glance:

```
Opus 4.8 | 84k/1m tokens (8%) | $2.41 | 3 sessions
```

- **Model** — the active model's display name
- **Tokens** — context used (in thousands) out of the total context window (in millions), plus the percentage full
- **Cost** — total USD spent in the current session
- **Sessions** — how many Claude Code sessions are currently running on your machine

## Requirements

- [`jq`](https://jqlang.github.io/jq/) on your `PATH` — `brew install jq` (macOS) or `apt install jq` (Debian/Ubuntu)
- Claude Code (the status line JSON schema this script reads is provided by Claude Code)

## Install

### Option A — one line, no clone

`install.sh` is self-contained (it embeds every file it installs), so you can pipe it straight from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/guptesachin/claude-statusline/main/install.sh | bash
```

Or, if you've already cloned the repo:

```bash
git clone https://github.com/guptesachin/claude-statusline.git
cd claude-statusline
./install.sh
```

The installer writes `statusline.sh`, `my-usd.sh`, `my-tokens.sh`, and the `/my-usd` and `/my-tokens` commands into `~/.claude/`, makes the scripts executable, and adds the `statusLine` block to `~/.claude/settings.json` (backing the file up first). It will **not** overwrite an existing `statusLine` setting without asking, and re-running it is safe.

### Option B — manual

1. Copy the script into your Claude config directory and make it executable:

   ```bash
   mkdir -p ~/.claude
   cp statusline.sh ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Add this to `~/.claude/settings.json` (merge it into the existing top-level object):

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh"
     }
   }
   ```

3. Start a new Claude Code session (or run `/config`) to see it.

## Bonus: usage & spend tracking (`/my-usd`)

The status line quietly logs one small JSON file per session to
`~/.claude/session-logs/` (each file is overwritten on refresh, so it always
holds that session's latest cumulative cost). `my-usd.sh` aggregates
those into a report:

```
$ ~/.claude/my-usd.sh
=== Claude Code usage summary ===
Sessions logged : 80
Last 24 hours   : $383.25
Last 7 days     : $537.73
Last 30 days    : $1038.79
All-time (est.) : $4390.12

=== Spend by model (all-time, est.) ===
...
```

Inside Claude Code you can run it as the **`/my-usd`** slash command (installed to `~/.claude/commands/`).

> **What the dollar figures mean:** `cost_usd` is Claude Code's *estimate* of
> API-equivalent token cost. On a **Pro/Max subscription** you don't pay this —
> it's a usage signal, not a bill. On **API/usage billing** it's a close
> estimate. It only covers sessions run *after* you installed the status line.

If you only want the status bar and not the logging, delete the logging block
in `statusline.sh` (it's clearly marked).

## Bonus: token usage (`/my-tokens`)

`/my-usd` answers *what did this cost*. `/my-tokens` answers *where did the
tokens go* — and it reads a completely different data source to do it.

The session logs above only carry **context-window snapshots** (how full the
window was at the last refresh). Those are not cumulative and must not be
summed. Real token counts live in Claude Code's session transcripts under
`~/.claude/projects/**/*.jsonl`, which `my-tokens.sh` reads directly:

```
$ ~/.claude/my-tokens.sh
=== Claude Code token usage ===
Requests logged : 19550
Sessions        : 116
Last 24 hours   : 195.83M
Last 7 days     : 1.26B
Last 30 days    : 2.67B
All-time        : 4.96B
Token split     : 1.67M in / 21.69M out / 139.64M cache-w / 4.80B cache-r
Cache reuse     : 34.4x all-time, 51.5x last 7d

=== Tokens by model (all-time) ===
    TOTAL   REQS        IN       OUT   CACHE_W    CACHE_R  MODEL
    1.72B   6026    47.94k     4.63M    32.68M      1.68B  claude-opus-5
    1.31B   5096     1.17M     8.77M    47.76M      1.25B  claude-opus-4-8
    1.03B   3397   141.80k     6.27M    31.18M    991.18M  claude-opus-4-7
...

=== 10 most recent sessions ===
    TOTAL  WHEN     PROJECT
    1.79M  0h ago   claude-statusline
  170.52M  4h ago   my-api-service
...
```

Inside Claude Code, run it as the **`/my-tokens`** slash command. It takes a
couple of seconds — it rescans every transcript on disk each run, no cache.

**Cache reuse** is how many times the average cached token was read back, all-time
versus the last 7 days. It is deliberately not a hit-rate percentage: reads so
dominate writes that every percentage formulation pins at 97-98% and never
moves, which tells you nothing. The ratio has real spread, so a busy week of
long sessions visibly separates from a week of short ones.

> **Token volume is not proportional to dollars.** Cache reads are ~97% of the
> volume for a typical Claude Code user and are billed at a fraction of fresh
> input, so a big token number is not a big bill. Use `/my-usd` for spend.

Two more differences from `/my-usd`:

- **Coverage.** `/my-tokens` sees every transcript still on disk, including
  sessions from before you installed the status line. `/my-usd` only sees
  sessions run *after* installation. Conversely, transcripts are subject to
  Claude Code's own cleanup, so old sessions can age out of `/my-tokens` while
  their spend lives on in `/my-usd`.
- **Model names.** `/my-usd` shows display names (`Opus 5 (1M context)`);
  `/my-tokens` shows API model IDs (`claude-opus-5`). Transcripts don't record
  the 1M-context marker, so the two model tables can't be joined reliably —
  which is also why `/my-tokens` has no price table and reports no dollars.

### If you write your own transcript tooling

Claude Code writes **one JSONL record per content block**, so a single response
containing thinking + text + a tool call becomes three records sharing one
`requestId` and one byte-identical `usage` object. Summing them naively
inflates totals by roughly **2.15x**. `my-tokens.sh` keys on `requestId` so
each API response counts once. Two smaller traps it also handles: transcripts
nest in three different directory shapes (use `find`, not a fixed-depth glob),
and `<synthetic>` records are local API-error placeholders that should be
skipped.

## How it works

Claude Code pipes a JSON object describing the current session into your status
line command on **stdin**, and renders whatever the command prints on **stdout**.
This script reads the fields it needs with `jq` and prints one line. That's the
whole contract — so you can customize the output by editing the final `echo`.

Fields available on stdin include `model.display_name`, `context_window.*`,
`cost.total_cost_usd`, `session_id`, and `cwd`. See the
[status line docs](https://docs.claude.com/en/docs/claude-code/statusline) for the full schema.

## Customizing

The last line of `statusline.sh` builds the output string — edit it to add,
remove, or reorder segments. For example, to append the current directory:

```bash
CWD=$(echo "$DATA" | jq -r '.cwd // ""')
echo "${MODEL} | ${USED_K}k/${TOTAL_M}m tokens (${CTX_PCT}%) | \$${COST} | ${RUNNING} sessions | ${CWD##*/}"
```

## Contributing

`install.sh` is **generated** — it embeds the current contents of `statusline.sh`,
`my-usd.sh`, `my-tokens.sh`, `commands/my-usd.md`, and `commands/my-tokens.md` as
heredocs. Don't edit `install.sh` by hand.
After changing any of those source files, regenerate it:

```bash
./build-install.sh
```

## License

MIT — see [LICENSE](LICENSE).
