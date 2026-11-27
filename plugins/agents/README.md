# agents

What a coding session delegates, native in each harness:

- **The expert**: writes a plan, designs a critical part or takes apart a stuck bug, as a document; changes no
  product code. How it works is the skill [`expert`](skills/expert/SKILL.md), one text for both harnesses.
- **Cheaper models for routine work**: each session gets a short note ([prompt.md](prompt.md)) that sends work
  needing no judgement to a subagent on a cheaper model, which the agent names when it starts the subagent.

The roles of a workflow (its coder, its reviewer) are not here: their text belongs to the workflow that runs them.

## Install

Install and enable the plugin as the [root README](../../README.md#install) says.

### Claude

The expert is the subagent `agents:expert` ([agents/expert.md](agents/expert.md)): model `fable`, the skill loaded
into its context from the start.

### Codex

A Codex plugin cannot ship an agent role, so the role is one file of the session's `CODEX_HOME`,
`$CODEX_HOME/agents/expert.toml`, that points at the skill:

```toml
name = "expert"
description = "The expert a coder consults for the plan or the design of a critical part, a disputed design choice, or a bug after two failed attempts. Writes a document, changes no product code."
developer_instructions = "Work as the `expert` skill of the `agents` plugin says."
model = "gpt-6.2-astra"
model_reasoning_effort = "high"
```

The agent starts it with `spawn_agent` and `agent_type = "expert"`.

## Settings

| Variable | Default | What |
|---|---|---|
| `AGENTS_CHEAP_MODELS` | `sonnet, haiku` | the cheaper models the note names, the cheapest last |

The default fits Claude. Give a Codex session the models of its provider, e.g.
`AGENTS_CHEAP_MODELS="gpt-6.1-terra, gpt-6-luna"`.

## What the host needs

- `jq` for the hook: `mise use -g jq`.
