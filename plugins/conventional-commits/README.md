# conventional-commits

Git refuses a commit of a Claude or Codex session whose subject is not a Conventional Commit: a lowercase type, an
optional scope in parentheses, an optional `!` and a description, e.g. `feat(api)!: change the response format`.
Bodies and trailers are free. The session start gives the agent one example subject ([prompt.md](prompt.md)). Every
commit made in the session is checked, in any repository.

## Install

Claude: `/plugin install conventional-commits --marketplace kvokka/kvokka-harness-plugins`. Codex and T3: see the
[root README](../../README.md).

## How it works

Git runs the check as a named `commit-msg` hook from its config, beside the repository's own hooks. The session's Git
includes `~/.local/state/kvokka-harness-plugins/conventional-commits/gitconfig`, and the plugin's `SessionStart`
hook rewrites that file each time to name the check of the plugin as installed now (the installed plugin lives in a
versioned path). Git skips an include file that does not exist, so commits are checked once a session has started
with the plugin.

## What the host needs

- Git with configured hooks (`git hook list`), and `jq`.
- The include in the environment of the session (a plugin cannot set it). Use the absolute path of your home: T3 does
  not expand `~` or `$HOME` in an instance's environment.

```sh
GIT_CONFIG_COUNT=1
GIT_CONFIG_KEY_0=include.path
GIT_CONFIG_VALUE_0=/home/<you>/.local/state/kvokka-harness-plugins/conventional-commits/gitconfig
```

With the agent-mail plugin as well, include both files:

```sh
GIT_CONFIG_COUNT=2
GIT_CONFIG_KEY_0=include.path
GIT_CONFIG_VALUE_0=/home/<you>/.local/state/kvokka-harness-plugins/conventional-commits/gitconfig
GIT_CONFIG_KEY_1=include.path
GIT_CONFIG_VALUE_1=/home/<you>/.local/state/kvokka-harness-plugins/agent-mail/gitconfig
```

The T3 instance snippet is in the [root README](../../README.md#t3-provider-instances).
