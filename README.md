# kvokka-harness-plugins

Plugins for [Claude Code](https://code.claude.com) and the [OpenAI Codex CLI](https://github.com/openai/codex). Each
plugin is one directory that both harnesses load natively: two manifests, shared hooks, scripts, skills and MCP
config. Install them from this marketplace and enable the ones a session needs; they also run under
[T3 Code](https://github.com/pingdotgg/t3code) ([Using with T3 Code](#using-with-t3-code)).

| Plugin | What |
|---|---|
| [dcg](plugins/dcg/README.md) | every shell command goes through `dcg` (destructive_command_guard) before it runs |
| [conventional-commits](plugins/conventional-commits/README.md) | the agent writes Conventional Commit subjects; a prek hook of the repository enforces them |
| [context-budget](plugins/context-budget/README.md) | past a soft context limit the agent wraps up; past a hard one the session stops, its state in a file |
| [shell-tools](plugins/shell-tools/README.md) | agents search with `rg` and `ast-grep` and read JSON with `toon` |
| [agent-mail](plugins/agent-mail/README.md) | agents in one repository coordinate through Agent Mail: a thread, path reservations, and a prek hook that refuses commits of held paths |
| [agents](plugins/agents/README.md) | skills `coder`, `reviewer` and `expert`: how each role works |
| [cache-warm](plugins/cache-warm/README.md) | agents know how long their prompt cache lives and keep it warm while they wait |

Each plugin's README says what the host needs and which environment variables it reads. The versions are in
[CHANGELOG.md](CHANGELOG.md).

## Tools

The plugins use tools of the host, each installed with one [mise](https://mise.jdx.dev) command. A hook that misses
a tool fails and names the command.

| Tool | Used by | Install |
|---|---|---|
| `jq` | conventional-commits, context-budget, shell-tools, agent-mail, cache-warm | `mise use -g jq` |
| `dcg` | dcg | `mise use -g github:Dicklesworthstone/destructive_command_guard` |
| `rg` | shell-tools | `mise use -g ripgrep` |
| `ast-grep` | shell-tools | `mise use -g ast-grep` |
| `toon` | shell-tools | `mise use -g github:Dicklesworthstone/toon_rust` |
| `mcp-agent-mail` | agent-mail | `mise use -g github:Dicklesworthstone/mcp_agent_mail_rust` |
| `prek` | the commit checks of conventional-commits and agent-mail | `mise use -g prek` |
| `python3` | `bin/codex-trusted` | `mise use -g python` |
| `git` | context-budget, agent-mail | the system's package manager (mise has no `git`) |

## Install

### Claude Code

```sh
claude plugin marketplace add kvokka/kvokka-harness-plugins
claude plugin install dcg@kvokka-harness-plugins     # and so on, one per plugin
```

A plugin installed this way is on in every session. To turn it on for some sessions only, disable it at user scope
and enable it in the settings of those sessions:

```sh
claude plugin disable context-budget@kvokka-harness-plugins
claude --settings '{"enabledPlugins":{"context-budget@kvokka-harness-plugins":true}}'
```

`claude plugin install --scope project` enables a plugin for one repository instead. To try a plugin of a local
checkout without installing it: `claude --plugin-dir ~/src/kvokka-harness-plugins/plugins/dcg` (repeat
`--plugin-dir` per plugin).

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

Sessions that need another set of plugins get a `CODEX_HOME` of their own (`CODEX_HOME=~/.codex-coder codex plugin
add ...`, then `CODEX_HOME=~/.codex-coder codex`).

Codex runs a plugin's hook only once the user trusts it (`/hooks` in the TUI), and any change of the plugin, an
update included, makes it untrusted again. Until Codex trusts plugin hooks on its own, run Codex through
[`bin/codex-trusted`](bin/codex-trusted): it trusts the hooks of this marketplace's enabled plugins in its
`CODEX_HOME` (through `codex app-server`), then runs the real `codex` (the first one on `PATH` that is not the wrapper,
or `CODEX_TRUSTED_REAL`) with the same arguments. A failure of the trust step is one line on stderr, and Codex runs
all the same. It needs `python3`:

```sh
curl -fsSL https://raw.githubusercontent.com/kvokka/kvokka-harness-plugins/main/bin/codex-trusted \
  -o ~/.local/bin/codex-trusted && chmod +x ~/.local/bin/codex-trusted
codex-trusted     # instead of codex, with the same arguments
```

### Settings

The plugins read environment variables, listed in each plugin's README. Set them the usual way: in the shell that
starts the harness (`CONTEXT_BUDGET_SOFT=200000 claude`), or for Claude in the `env` of its settings.

When the harness compacts the context is its own setting, which a plugin cannot set. Have both compact at about
600000 tokens, past context-budget's hard limit:

- Claude: `autoCompactWindow` 633000 in its settings, or `claude --settings '{"autoCompactWindow":633000}'`. Claude
  compacts at the window less 33000 tokens (20000 kept for the answer, 13000 for the summary), and caps the window
  at the model's own.
- Codex: `model_auto_compact_token_limit = 600000` in `config.toml`, or `codex -c
  model_auto_compact_token_limit=600000`.

See [context-budget](plugins/context-budget/README.md#settings) for how the two limits meet.

## Using with T3 Code

A provider instance in `~/.t3/userdata/settings.json` gives its sessions the plugins, the environment and the
launch arguments. T3 expands neither `~` nor `$HOME` in an instance's paths and environment: write absolute paths
(`/home/<you>/...` below).

A Claude instance. With the plugins installed and disabled at user scope (above), the instance enables its own:

```json
{
  "providerInstances": {
    "claude-coder": {
      "driver": "claudeAgent",
      "displayName": "Claude coder",
      "enabled": true,
      "config": {
        "launchArgs": "--settings '{\"enabledPlugins\":{\"conventional-commits@kvokka-harness-plugins\":true,\"agent-mail@kvokka-harness-plugins\":true,\"context-budget@kvokka-harness-plugins\":true},\"autoCompactWindow\":633000}'"
      },
      "environment": [
        { "name": "CONTEXT_BUDGET_SOFT", "value": "300000" },
        { "name": "CONTEXT_BUDGET_HARD", "value": "420000" }
      ]
    }
  }
}
```

A Codex instance with a `CODEX_HOME` of its own (`homePath`), where its plugins are installed and enabled
(`CODEX_HOME=/home/<you>/.t3/codex-coder codex plugin add ...`), run through the trust wrapper (`binaryPath`):

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
        "launchArgs": "-c model_auto_compact_token_limit=600000"
      },
      "environment": [
        { "name": "CONTEXT_BUDGET_SOFT", "value": "300000" },
        { "name": "CONTEXT_BUDGET_HARD", "value": "420000" }
      ]
    }
  }
}
```

Under T3, the `agents` coder consults the expert through T3's `delegate_task`; its README says more.

## Development

The rules for agents working on this repository are in [AGENTS.md](AGENTS.md). `tests/run` runs the tests and
`shellcheck`; CI runs it on each push.
