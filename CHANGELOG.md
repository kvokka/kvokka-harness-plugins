# Changelog

Each plugin has its own version; its section lists its releases, newest first.

## Repository tags

The repository is tagged `vMAJOR.MINOR.PATCH` for the hooks of its `.pre-commit-hooks.yaml`, which a
`.pre-commit-config.yaml` pins by `rev`.

### v0.2.0

- The hook `agent-mail-reservations` (agent-mail 0.2.0).

## dcg

### 0.1.1

- A missing `dcg` is reported with the `mise use -g` command that installs it.

### 0.1.0

- Check each shell command of a Claude or Codex session with the host's `dcg` before it runs; without `dcg` no
  command runs.

## shell-tools

### 0.1.1

- A missing `jq` is reported with `mise use -g jq`; the README names the mise command of each tool.

### 0.1.0

- Tell each Claude or Codex session and subagent to search with `rg` and `ast-grep` and to read JSON with `toon`.

## conventional-commits

### 0.2.0

- The plugin is the session-start hint only; conventional-pre-commit under prek checks the commits, configured per
  repository. The Git commit-msg check, its gitconfig and the `GIT_CONFIG_*` setup are gone.
- The hint names the types conventional-pre-commit accepts and asks for `revert: <subject>` in place of Git's
  `Revert "..."`, which that check refuses.
- A missing `jq` is reported with `mise use -g jq`.

### 0.1.0

- Git refuses a commit of a Claude or Codex session whose subject is not a Conventional Commit, merge and revert
  subjects aside; the session start gives the agent an example subject.

## context-budget

### 0.1.1

- A missing `jq` is reported with `mise use -g jq`.
- The README sets the harness's compaction at about 600000 tokens: Claude `autoCompactWindow` 633000, Codex
  `model_auto_compact_token_limit` 600000.

### 0.1.0

- Bound the context of a Claude or Codex session: a wrap-up note past `CONTEXT_BUDGET_SOFT`, no subagents past it,
  and a stop with a dump of the work's state past `CONTEXT_BUDGET_HARD`, also when the harness tries to compact
  past it.

## agent-mail

### 0.2.0

- The commit check is the prek (pre-commit) hook `agent-mail-reservations` of this repository's
  `.pre-commit-hooks.yaml`, installed per repository, in place of a Git include in the session's environment.
- A missing `jq` or `mcp-agent-mail` is reported with the `mise use -g` command that installs it.

### 0.1.0

- Coordinate Claude and Codex agents in one repository through one Agent Mail server per machine, started and
  restarted by the plugin: a mail identity per session, the protocol in its context, a Git check that refuses commits
  of paths another agent holds, and the release of reservations at the session's end.

## agents

### 0.1.0

- Skills `coder`, `reviewer` and `expert` for Claude and Codex: how each role works, with the output format left to
  the caller.
