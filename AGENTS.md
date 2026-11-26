# kvokka-harness-plugins: rules for agents

Plugins that work in both Claude Code and OpenAI Codex CLI from one directory each. What each plugin does is in its
own `README.md`; how to install them is in the root `README.md`.

## Layout

```
.claude-plugin/marketplace.json            Claude marketplace: every plugin, source ./plugins/<name>
.agents/plugins/marketplace.json           Codex marketplace: the same plugins
plugins/<name>/.claude-plugin/plugin.json  Claude manifest
plugins/<name>/.codex-plugin/plugin.json   Codex manifest (needs "interface": {"displayName": ...})
plugins/<name>/hooks/hooks.json            hooks of both harnesses; commands use ${CLAUDE_PLUGIN_ROOT}
plugins/<name>/...                         scripts, prompts, skills, .mcp.json
bin/codex-trusted                          the temporary Codex trust wrapper
tests/run                                  the test runner; tests/<name>.sh and tests/*.py are its tests
```

## Constraints

1. Nothing of loop-manager: no beads or tracker, no dollar budgets, no daemons, no T3-notify/run-card glue, no
   `LOOP_MANAGER_*` variables, no `loop-manager` command.
2. Do not re-implement what T3 or its workflows do natively (lessons, notifications, run cards, orchestration). T3's
   own tools come first; any extra needs the owner's approval first.
3. One plugin is one directory for both harnesses: two manifests, shared hooks and scripts. No copies of code or
   prompts per harness.
4. A plugin works out of the box once installed from the marketplace: no clone of this repository, no variable that
   points at it.
5. Native harness mechanisms only. What a harness cannot do through a plugin, it does not get; do not emulate it.
6. Do not replace the harness's system prompt, and do not layer a role on top of the harness's own agents.
7. Instructions for agents come from a plugin (a hook or a skill), never pasted into the user's CLAUDE.md/AGENTS.md.
8. No systemd, Pitchfork or other service manager: a long-lived service a plugin needs is started and restarted by
   the plugin itself.
9. No script edits the config of T3 or of a harness. Setup is README snippets, including the env variables needed.
10. No `doctor` and no version checks: a hook that misses a tool fails with a clear reason.
11. Less code is better; no stubs, no code "for later".
12. The product is in English. Tests live in `tests/`; CI runs them and `shellcheck`.
13. The Codex trust wrapper is temporary: delete it once Codex or T3 trusts plugin hooks on their own.

## Working on a plugin

- Shell scripts are POSIX `sh` or `bash` with `set -eu` and pass `shellcheck`. Hooks read the hook input as JSON on
  stdin and answer in a form both harnesses accept; where they differ (Codex rejects `continue` on `PreToolUse`), the
  script tells them apart by the input (`turn_id` is Codex's).
- Test a hook by feeding it JSON on stdin; never run live models (`claude -p`, `codex exec`, T3 threads).
- Run `tests/run` and `shellcheck` over every script before handing work over.
- A change to a plugin bumps its SemVer in both manifests (they always agree) and adds an entry to its section of
  `CHANGELOG.md`. Any change to a plugin's files makes Codex see its hooks as modified, so they need trust again.
- Docs describe how things work now: no history. No absolute paths of anyone's machine (use `~`).
- Commits are small, atomic, with Conventional Commit subjects.
