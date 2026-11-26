# context-budget

Bounds the context of a Claude or Codex session. Past a soft limit the agent is told to wrap up: finish or roll back
the step at hand, commit, start nothing new, call no subagents, and give its summary (what is done, what did not
work, what is started and not finished) as its final answer; a subagent returns that summary to its caller. Past a
hard limit the session is stopped and the state of its work is written to a file the stop names. The context is
never compacted.

## Install

Claude: `/plugin install context-budget --marketplace kvokka/kvokka-harness-plugins`. Codex and T3: see the
[root README](../../README.md).

## Settings

| Variable | Default | What |
|---|---|---|
| `CONTEXT_BUDGET_SOFT` | `300000` | tokens of context past which the agent is told to wrap up |
| `CONTEXT_BUDGET_HARD` | `420000` | tokens of context past which the session is stopped |
| `CONTEXT_BUDGET_STEP` | `30000` | tokens the context grows past the soft limit between two notes |

Compaction is off by harness settings, which a plugin cannot set; give them in the session's launch arguments:

- Claude: `--settings '{"autoCompactWindow":1000000}'`. Claude then compacts at about 967k tokens, past the hard
  limit, and the plugin blocks a compaction that comes earlier (`/compact` included).
- Codex: `-c model_auto_compact_token_limit=420000`, the hard limit. Codex's `PreCompact` takes no block, so its
  attempt to compact is where the plugin stops the session.

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
- `PreCompact`: on Claude blocked below hard and a stop past it; on Codex a stop.

`<data>` is the plugin's data directory, `CLAUDE_PLUGIN_DATA` (both harnesses set it). The agent hears of the soft
limit only: the stop is a safety net a session that wraps up in time never meets.

## On Codex

- **The budget is bounded by the model's window.** Codex compacts at 90% of the window at most, whatever the limit
  says. The defaults do not fit a window of 272000 tokens: give such an instance smaller limits, e.g.
  `CONTEXT_BUDGET_SOFT=180000`, `CONTEXT_BUDGET_HARD=240000` and `-c model_auto_compact_token_limit=240000`.
- **A tool hook does not end a turn.** Codex's `PreToolUse` takes only the denial of one call, so past hard every call
  is denied, and a `PostToolUse` answer of `continue: false` replaces the tool's result with the reason.
- **The measure is one model request late**, since Codex writes the usage of a request after its tools ran; and it
  runs no `PostToolUse` after a call that failed, so the note follows a successful call.

## What the host needs

`jq` and `git` on the `PATH` of the hooks.
