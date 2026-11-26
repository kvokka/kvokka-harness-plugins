# context-budget

Bounds the context of a Claude or Codex session. Past a soft limit the agent is told to wrap up: finish or roll back
the step at hand, commit, start nothing new, call no subagents, and give its summary (what is done, what did not
work, what is started and not finished) as its final answer; a subagent returns that summary to its caller. Past a
hard limit the session is stopped and the state of its work is written to a file the stop names. With the harness
settings below, the session stops before the harness compacts its context.

## Install

Install and enable the plugin as the [root README](../../README.md#install) says.

## Settings

| Variable | Default | What |
|---|---|---|
| `CONTEXT_BUDGET_SOFT` | `300000` | tokens of context past which the agent is told to wrap up |
| `CONTEXT_BUDGET_HARD` | `420000` | tokens of context past which the session is stopped |
| `CONTEXT_BUDGET_STEP` | `30000` | tokens the context grows past the soft limit between two notes |

When the harness compacts is its own setting, which a plugin cannot set. Set it past the hard limit, at about 600000
tokens, so that the session stops before it compacts:

- Claude: `autoCompactWindow` 633000 in its settings, or `claude --settings '{"autoCompactWindow":633000}'`. Claude
  compacts at the window less 33000 tokens, and caps the window at the model's own: on a model with a 200k window it
  compacts at about 167k, below the default limits: give such a session smaller ones.
- Codex: `model_auto_compact_token_limit = 600000` in `config.toml`, or `codex -c
  model_auto_compact_token_limit=600000`.

An attempt to compact past the hard limit stops the session; one below it (Claude's `/compact`, or a compaction
setting below the hard limit) goes ahead, and the plugin says nothing.

## How it works

The hook `hooks/budget` runs on five events. The context of an agent is the size of the last answer of its model in
its transcript: on Claude input, cache writes, cache reads and output (a subagent's from its own transcript,
`<session>/subagents/agent-<id>.jsonl`); on Codex `last_token_usage.total_tokens` of the last `token_count` event of
the rollout.

- `SessionStart`, `SubagentStart`: the agent learns its soft limit and that a note will tell it to wrap up. The
  session keeps the commit it starts on, for the dump.
- `PostToolUse`, past soft: the note joins the agent's context, and again each time the context grows by the step.
- `PreToolUse`, past soft: a call of a subagent (Claude `Agent` or `Task`, Codex `spawn_agent`) is denied.
- Past hard, on a tool hook: the state of the work goes to `<data>/<session_id>.md` (a subagent's to
  `<session_id>.agent-<id>.md`): `git status --short`, the commits since the session started, `git diff --stat`, the
  last tool calls and texts. The session stops, and every later tool call is denied. A subagent past its own hard
  limit stops alone.
- `PreCompact`, past hard: the same stop. Below hard the plugin answers nothing.

`<data>` is the plugin's data directory, `CLAUDE_PLUGIN_DATA` (both harnesses set it). Each session start deletes
the files there that are older than 7 days, dumps included. The agent hears of the soft
limit only: the stop is a safety net a session that wraps up in time never meets.

## On Codex

- **The budget is bounded by the model's window.** Codex compacts at 90% of the window at most, whatever the limit
  says. The defaults do not fit a window of 272000 tokens: give such a session smaller limits, e.g.
  `CONTEXT_BUDGET_SOFT=180000` and `CONTEXT_BUDGET_HARD=240000`.
- **A tool hook does not end a turn.** Codex's `PreToolUse` takes only the denial of one call, so past hard every call
  is denied, and a `PostToolUse` answer of `continue: false` replaces the tool's result with the reason.
- **The measure is one model request late**, since Codex writes the usage of a request after its tools ran; and it
  runs no `PostToolUse` after a call that failed, so the note follows a successful call.

## What the host needs

- `jq`: `mise use -g jq`.
- `git`, from the system's package manager, for the dump of a stopped session.
