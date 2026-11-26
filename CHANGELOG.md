# Changelog

Each plugin has its own version; its section lists its releases, newest first.

## dcg

### 0.1.0

- Check each shell command of a Claude or Codex session with the host's `dcg` before it runs; without `dcg` no
  command runs.

## shell-tools

### 0.1.0

- Tell each Claude or Codex session and subagent to search with `rg` and `ast-grep` and to read JSON with `toon`.

## conventional-commits

### 0.1.0

- Git refuses a commit of a Claude or Codex session whose subject is not a Conventional Commit; the session start
  gives the agent an example subject.

## context-budget

### 0.1.0

- Bound the context of a Claude or Codex session: a wrap-up note past `CONTEXT_BUDGET_SOFT`, no subagents past it,
  and a stop with a dump of the work's state past `CONTEXT_BUDGET_HARD`; compaction is blocked or stops the session.

## agent-mail

### 0.1.0

- Coordinate Claude and Codex agents in one repository through one Agent Mail server per machine, started and
  restarted by the plugin: a mail identity per session, the protocol in its context, a Git check that refuses commits
  of paths another agent holds, and the release of reservations at the session's end.

## agents

### 0.1.0

- Skills `coder`, `reviewer` and `expert` for Claude and Codex: how each role works, with the output format left to
  the caller.
