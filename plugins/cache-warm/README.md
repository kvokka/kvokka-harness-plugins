# cache-warm

Each Claude or Codex session, and each subagent it starts, learns how long its prompt cache lives and keeps it warm
while it waits: no single wait is longer than the cache's lifetime less a minute, long work runs in the background
and is checked on in time, and after ten lifetimes of waiting on one thing the agent lets the cache go. The note is
[prompt.md](prompt.md).

Neither harness renews the cache of an agent that waits: a subagent's requests do not count for its caller, and a
tool call that outlasts the cache makes the next request write the whole context again. A cache write costs 1.25
times the input price, a cached read 0.1 times (Claude) or 0.05 times (GPT), so a check every lifetime pays off for
about ten lifetimes.

## Install

Install and enable the plugin as the [root README](../../README.md#install) says.

## Settings

| Variable | Default | What |
|---|---|---|
| `CACHE_WARM_TTL` | `5` | minutes the prompt cache of the session lives, told to the agents |

Set it to the lifetime the harness really asks for; the plugin cannot change that:

- Claude: 5 minutes with `"promptCacheTtl": "5m"` and `"subagentPromptCacheTtl": "5m"` in its settings. Without
  them the main conversation of a subscription session gets 1 hour (`CACHE_WARM_TTL=60`) and its subagents 5 minutes.
- Codex: it has no setting; the API keeps the cache of GPT-5.6 and later models 30 minutes (`CACHE_WARM_TTL=30`).

## What the host needs

- `jq` for the hook: `mise use -g jq`.
