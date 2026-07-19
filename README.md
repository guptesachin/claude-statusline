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

The installer writes `statusline.sh`, `my-usd.sh`, and the `/my-usd` command into `~/.claude/`, makes the scripts executable, and adds the `statusLine` block to `~/.claude/settings.json` (backing the file up first). It will **not** overwrite an existing `statusLine` setting without asking, and re-running it is safe.

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
`my-usd.sh`, and `commands/my-usd.md` as heredocs. Don't edit `install.sh` by hand.
After changing any of those source files, regenerate it:

```bash
./build-install.sh
```

## License

MIT — see [LICENSE](LICENSE).
