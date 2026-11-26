# kvokka-harness-plugins

Plugins for [Claude Code](https://code.claude.com) and the [OpenAI Codex CLI](https://github.com/openai/codex). Each
plugin is one directory that both harnesses load natively: two manifests, shared hooks, scripts, skills and MCP
config. They suit sessions run by hand or by [T3 Code](https://github.com/pingdotgg/t3code), whose provider instances
choose which plugins a session gets.

| Plugin | What |
|---|---|
| [dcg](plugins/dcg/README.md) | every shell command goes through `dcg` (destructive_command_guard) before it runs |
| [conventional-commits](plugins/conventional-commits/README.md) | Git refuses a commit of the session whose subject is not a Conventional Commit |
| [context-budget](plugins/context-budget/README.md) | past a soft context limit the agent wraps up; past a hard one the session stops, its state in a file |
| [shell-tools](plugins/shell-tools/README.md) | agents search with `rg` and `ast-grep` and read JSON with `toon` |
| [agent-mail](plugins/agent-mail/README.md) | agents in one repository coordinate through Agent Mail: a thread, path reservations, refused commits of held paths |
| [agents](plugins/agents/README.md) | skills `coder`, `reviewer` and `expert`: how each role works |

Each plugin's README says what the host needs and which environment variables it reads. The versions are in
[CHANGELOG.md](CHANGELOG.md).

## Install

### Claude Code

```sh
claude plugin marketplace add kvokka/kvokka-harness-plugins
claude plugin install dcg@kvokka-harness-plugins     # and so on, one per plugin
```

Or, without installing, load a plugin of a local checkout for one session: `claude --plugin-dir
~/src/kvokka-harness-plugins/plugins/dcg` (repeat `--plugin-dir` per plugin).

### Codex

```sh
codex plugin marketplace add kvokka/kvokka-harness-plugins
codex plugin add dcg@kvokka-harness-plugins          # and so on, one per plugin
```

This enables each plugin in `$CODEX_HOME/config.toml`:

```toml
[plugins."dcg@kvokka-harness-plugins"]
enabled = true
```

Codex runs a plugin's hook only once the user trusts it (`/hooks` in the TUI), and any change of the plugin, an
update included, makes it untrusted again. Until Codex or T3 trusts plugin hooks on their own, run Codex through
[`bin/codex-trusted`](bin/codex-trusted): it trusts the hooks of this marketplace's enabled plugins in its
`CODEX_HOME` (through `codex app-server`), then runs the real `codex` (the first one on `PATH` that is not the wrapper,
or `CODEX_TRUSTED_REAL`) with the same arguments. A failure of the trust step is one line on stderr, and Codex runs
all the same. It needs `python3`:

```sh
curl -fsSL https://raw.githubusercontent.com/kvokka/kvokka-harness-plugins/main/bin/codex-trusted \
  -o ~/.local/bin/codex-trusted && chmod +x ~/.local/bin/codex-trusted
```

## T3 provider instances

A provider instance in `~/.t3/userdata/settings.json` gives its sessions the plugins, the environment and the
launch arguments. T3 expands neither `~` nor `$HOME`: write absolute paths (`/home/<you>/...` below).

A Claude instance. Install the plugins from the marketplace and disable them at user scope (`claude plugin disable
dcg@kvokka-harness-plugins`, and so on), so that only the instances that enable them in `--settings` get them:

```json
{
  "providerInstances": {
    "claude-coder": {
      "driver": "claudeAgent",
      "displayName": "Claude coder",
      "enabled": true,
      "config": {
        "launchArgs": "--settings '{\"enabledPlugins\":{\"conventional-commits@kvokka-harness-plugins\":true,\"agent-mail@kvokka-harness-plugins\":true,\"context-budget@kvokka-harness-plugins\":true},\"autoCompactWindow\":1000000}'"
      },
      "environment": [
        { "name": "GIT_CONFIG_COUNT", "value": "2" },
        { "name": "GIT_CONFIG_KEY_0", "value": "include.path" },
        { "name": "GIT_CONFIG_VALUE_0", "value": "/home/<you>/.local/state/kvokka-harness-plugins/conventional-commits/gitconfig" },
        { "name": "GIT_CONFIG_KEY_1", "value": "include.path" },
        { "name": "GIT_CONFIG_VALUE_1", "value": "/home/<you>/.local/state/kvokka-harness-plugins/agent-mail/gitconfig" },
        { "name": "CONTEXT_BUDGET_SOFT", "value": "300000" },
        { "name": "CONTEXT_BUDGET_HARD", "value": "420000" }
      ]
    }
  }
}
```

A Codex instance with a `CODEX_HOME` of its own (`homePath`), where conventional-commits and context-budget are
installed and enabled as above (`CODEX_HOME=/home/<you>/.t3/codex-coder codex plugin add ...`), run through the trust
wrapper:

```json
{
  "providerInstances": {
    "codex-coder": {
      "driver": "codex",
      "displayName": "Codex coder",
      "enabled": true,
      "config": {
        "homePath": "/home/<you>/.t3/codex-coder",
        "binaryPath": "/home/<you>/.local/bin/codex-trusted",
        "launchArgs": "-c model_auto_compact_token_limit=240000"
      },
      "environment": [
        { "name": "GIT_CONFIG_COUNT", "value": "1" },
        { "name": "GIT_CONFIG_KEY_0", "value": "include.path" },
        { "name": "GIT_CONFIG_VALUE_0", "value": "/home/<you>/.local/state/kvokka-harness-plugins/conventional-commits/gitconfig" },
        { "name": "CONTEXT_BUDGET_SOFT", "value": "180000" },
        { "name": "CONTEXT_BUDGET_HARD", "value": "240000" }
      ]
    }
  }
}
```

- `GIT_CONFIG_*`: the Git include of the commit checks of conventional-commits and agent-mail; list only the plugins
  the instance has, since agent-mail refuses the commits of a session without a mail name.
- `CONTEXT_BUDGET_*` and the compaction settings: see [context-budget](plugins/context-budget/README.md#settings).
  Claude never compacts below about 967k tokens with `autoCompactWindow` at 1000000; Codex compacts at
  `model_auto_compact_token_limit`: set it to the hard limit, so that its attempt to compact stops the session.
- `AGENT_MAIL_*`: see [agent-mail](plugins/agent-mail/README.md#settings).

## Development

The rules for agents working on this repository are in [AGENTS.md](AGENTS.md). `tests/run` runs the tests and
`shellcheck`; CI runs it on each push.
