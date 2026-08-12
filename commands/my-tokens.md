---
description: Summarize Claude Code token usage across all sessions
allowed-tools: Bash(~/.claude/my-tokens.sh)
---

Run `~/.claude/my-tokens.sh` and show the user its full output verbatim in a
code block. Then add a one-line takeaway about where their tokens are going —
which model or project dominates, and how the 7-day figure compares against a
seventh of the 30-day figure, if the numbers support saying so.

Note briefly that cache reads dominate these totals and are billed at a
fraction of fresh input tokens, so token volume is *not* proportional to
spend — `/my-usd` is the command for dollars.
