# agent-mail

Agents that work in the same repository at the same time (in worktrees or in one checkout) coordinate through
[Agent Mail](https://github.com/Dicklesworthstone/mcp_agent_mail_rust): they write to each other in a shared thread,
reserve the paths they edit, and see what the others hold. A pre-commit hook of this repository, run by
[prek](https://github.com/j178/prek), refuses a commit of a path another agent holds. One Agent Mail server serves
every session of the machine; the plugin starts it and restarts it when it exits.

## Install

Install and enable the plugin as the [root README](../../README.md#install) says. Then, in each repository where
agents work together, add the commit check to `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/kvokka/kvokka-harness-plugins
    rev: v0.2.0
    hooks:
      - id: agent-mail-reservations
```

and install its Git hook: `prek install`. `rev` is a tag of this repository, from the
[changelog](../../CHANGELOG.md#repository-tags): the one of the agent-mail release that is installed, since the hook
and the plugin share the session files under `~/.local/state/kvokka-harness-plugins/agent-mail/`.

The hook refuses the commits of a session whose registration failed, and lets through, with one warning line, those
of an agent session that has no agent-mail plugin. A Codex session whose plugin hooks are not trusted is such a
session: it commits with only the warning.

A Codex session with `sandbox_mode = "workspace-write"` runs `git commit`, and so prek, inside its sandbox. prek
writes its log and a lock in its home (`~/.cache/prek`, or `PREK_HOME`) at every run, so a home the sandbox cannot
write fails each commit. Prepare the hooks outside the sandbox once (`prek prepare-hooks` in the repository: it
fetches them, which needs the network), and make the home writable in `config.toml`:

```toml
[sandbox_workspace_write]
writable_roots = ["/home/<you>/.cache/prek"]
```

## What the host needs

- `mcp-agent-mail` (0.3.41 or newer): `mise use -g github:Dicklesworthstone/mcp_agent_mail_rust`.
- `jq`: `mise use -g jq`.
- `prek` for the commit check: `mise use -g prek`.
- `git`, `curl`, `flock` and `setsid` (util-linux), from the system's package manager.
- A session that reaches the server's port. A Codex session with `sandbox_mode = "workspace-write"` may have no
  network: its commits are then refused with "its reservations could not be checked".

## Settings

| Variable | Default | What |
|---|---|---|
| `AGENT_MAIL_PORT` | `8765` | the port of the server |
| `AGENT_MAIL_HOST` | `127.0.0.1` | the IPv4 address it listens on: `127.*`, `localhost`, or with a token `0.0.0.0` or another address |
| `AGENT_MAIL_TOKEN` | | the bearer clients from other hosts must send (8 characters or more) |
| `AGENT_MAIL_TTL` | `3600` | seconds a reservation lasts unless renewed, told to the agents |

The plugin's MCP server entry ([.mcp.json](.mcp.json)) is static: `http://127.0.0.1:8765/mcp/`. For another port,
add an entry of your own with that URL (the plugin's then finds no server, which is harmless): in Claude,
`claude mcp add --scope user --transport http agent-mail http://127.0.0.1:<port>/mcp/`; in Codex, in `config.toml`:

```toml
[mcp_servers.agent-mail]
url = "http://127.0.0.1:<port>/mcp/"
```

The token is for access from outside this machine, and loopback goes without it. An `AGENT_MAIL_HOST` that is not
loopback needs `AGENT_MAIL_TOKEN`, or the server is not started. With a token, a client on another host sends
`Authorization: Bearer <token>`, while the sessions of this machine still reach the server on loopback without one
(the server gets `HTTP_ALLOW_LOCALHOST_UNAUTHENTICATED=true` unless you set it otherwise), so the plugin's MCP entry
keeps working. With `0.0.0.0` the plugin's entry and hooks use `127.0.0.1`; with a specific address of the host
(say `192.168.1.5`) the hooks use that address, and the static entry of the plugin, on `127.0.0.1`, finds no server:
add an MCP entry of your own with that address as above.

## How it works

- **The server.** The `SessionStart` hook runs `bin/agent-mail-up`: under a lock in
  `~/.local/state/kvokka-harness-plugins/agent-mail/`, it checks `/health/readiness` on the port and, when nothing
  answers, starts a detached supervisor that runs `mcp-agent-mail serve` and restarts it when it exits (five quick
  failures in a row and it gives up until the next session start). The mailbox is in
  `~/.local/share/kvokka-harness-plugins/agent-mail`, the server's log in `server-<port>.log` of the state directory,
  started afresh by each supervisor. The hook waits at most 30 seconds for another session's start and 30 for the
  server to answer.
  Unless the user's Agent Mail config chooses a tool filter, the server offers the 12 tools of the protocol below. To
  stop it: `pkill -f 'agent-mail-up supervise'; pkill -f 'mcp-agent-mail serve'`.
- **A session's identity.** The session registers with `macro_start_session`. Its mail name is kept per harness
  session; under T3 Code, per T3 thread (`T3CODE_THREAD_ID`), so a later session of the thread is the same agent. The
  project key is the canonical common Git directory (`git rev-parse --git-common-dir`), shared by all worktrees of a
  repository, or the directory outside Git; each project has one thread, named after the repository. The session's
  context gets its mail name, project key, thread and inbox, and the protocol of [prompt.md](prompt.md). When the
  server is not up, the context says why, the session is kept with no name, and the commit check refuses its
  commits.
- **The commit check.** The hook `agent-mail-reservations` of [.pre-commit-hooks.yaml](../../.pre-commit-hooks.yaml)
  runs `bin/agent-mail pre-commit`. A commit by an agent session (`T3CODE_THREAD_ID`, `CLAUDE_CODE_SESSION_ID` or
  `CODEX_THREAD_ID` set) in the repository it registered in sends its staged paths, both sides of a rename, to
  `check_file_reservation_conflicts`; the session's mail name is read from
  `~/.local/state/kvokka-harness-plugins/agent-mail/`. A path another agent holds exclusively refuses the
  commit, naming the path and its holder; a check that cannot be made refuses it too, and so does a session kept
  with no name. An agent session the plugin never saw passes with a warning; other commits, a person's included,
  are not checked.
- **The end of a session.** `SessionEnd` releases the session's reservations; the TTL ends those of a session that
  did not end cleanly.
