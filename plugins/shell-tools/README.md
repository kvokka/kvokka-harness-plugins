# shell-tools

Each Claude or Codex session, and each subagent it starts, gets a short note in its context: search text with `rg`,
match and rewrite code by its structure with `ast-grep`, shortlist files with `rg` for `ast-grep`, and read JSON
compactly with `toon` (`foo | toon`, while programs that parse JSON keep getting JSON). The note is
[prompt.md](prompt.md).

## Install

Claude: `/plugin install shell-tools --marketplace kvokka/kvokka-harness-plugins`. Codex and T3: see the
[root README](../../README.md).

## What the host needs

`jq` for the hook. `rg`, `ast-grep` and `toon` on the `PATH` of the sessions: the plugin does not check them, and an
agent that misses one sees the shell's own error.
