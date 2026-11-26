# agents

Three skills, native in Claude and Codex, for the roles of a coding loop. Each says how to work in its role (the
order of work, context hygiene, implementation rules, strictness); the output format is set by whoever calls it: the
user, or a workflow step.

| Skill | What |
|---|---|
| [`coder`](skills/coder/SKILL.md) | implements a task: takes stock, closes the review's mandatory items first, commits in finished parts, keeps its context small, and knows when to consult the expert |
| [`reviewer`](skills/reviewer/SKILL.md) | reviews the work on a task: what to check, how strict to be, findings split into mandatory and desirable, a score 0-10 and a verdict |
| [`expert`](skills/expert/SKILL.md) | writes a plan, designs a critical part or takes apart a stuck bug, as a document; changes no product code |

Searches, runs and parallel pieces of work go to the harness's own subagents. The expert is a separate session the
coder briefs with the expert skill's text: under T3 Code the coder starts it with T3's `delegate_task` (its model
chosen with `target.model`); elsewhere the coder writes the brief to a file and asks the user to run the expert on
it.

## Install

Install and enable the plugin as the [root README](../../README.md#install) says. In Claude the skills are
`agents:coder`, `agents:reviewer` and `agents:expert`.
