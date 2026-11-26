# shell-tools

Each Claude or Codex session, and each subagent it starts, gets a short note in its context: search text with `rg`,
match and rewrite code by its structure with `ast-grep`, shortlist files with `rg` for `ast-grep`, and read JSON
compactly with `toon` (`foo | toon`, while programs that parse JSON keep getting JSON). The note is
[prompt.md](prompt.md).

## Install

Install and enable the plugin as the [root README](../../README.md#install) says.

## What the host needs

- `jq` for the hook: `mise use -g jq`.
- On the `PATH` of the sessions, unchecked (an agent that misses one sees the shell's own error):
  - `rg`: `mise use -g ripgrep`;
  - `ast-grep`: `mise use -g ast-grep`;
  - `toon`: `mise use -g github:Dicklesworthstone/toon_rust`.
