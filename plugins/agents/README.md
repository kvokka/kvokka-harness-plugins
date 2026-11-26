# agents

Three skills, native in Claude and Codex, for the roles of a coding loop. Each says how to work in its role (the
order of work, context hygiene, implementation rules, strictness); the output format is set by whoever calls it, a T3
workflow step or the user.

| Skill | What |
|---|---|
| [`coder`](skills/coder/SKILL.md) | implements a task: takes stock, closes the review's mandatory items first, commits in finished parts, keeps its context small, and knows when to consult the expert |
| [`reviewer`](skills/reviewer/SKILL.md) | reviews the work on a task: what to check, how strict to be, findings split into mandatory and desirable, a score 0-10 and a verdict |
| [`expert`](skills/expert/SKILL.md) | writes a plan, designs a critical part or takes apart a stuck bug, as a document; changes no product code |

The expert is no subagent: the coder calls T3's `delegate_task` (model chosen with `target.model`) with the expert
skill's text and its brief. Searches, runs and parallel pieces of work go to the harness's own subagents.

## Install

Claude: `/plugin install agents --marketplace kvokka/kvokka-harness-plugins`. Codex and T3: see the
[root README](../../README.md). In Claude the skills are `agents:coder`, `agents:reviewer` and `agents:expert`.
