# dcg

Every shell command of a Claude or Codex session goes through
[`dcg`](https://github.com/Dicklesworthstone/destructive_command_guard) (destructive_command_guard) before it runs. A
command `dcg` finds destructive (`git reset --hard`, `rm -rf` of a root, `git push --force`, ...) is denied, and the
agent sees the reason. The plugin brings no rules of its own: what is blocked is what the host's `dcg` and its config
say.

## Install

Claude: `/plugin install dcg --marketplace kvokka/kvokka-harness-plugins`. Codex and T3: see the
[root README](../../README.md).

## What the host needs

- `dcg` on the `PATH` of the session. Without it every shell command is refused, with a reason that says so.
- Its config, where `dcg` looks for it: `~/.config/dcg/config.toml` of the session's `HOME`, a `.dcg.toml` at the
  root of the repository, or the file `DCG_CONFIG` names. A Codex instance with a `HOME` of its own needs
  `DCG_CONFIG` in its environment.

`dcg install` is not needed: it writes the hook into the user's own Claude settings, while this plugin gives it only to
the sessions that enable the plugin.
