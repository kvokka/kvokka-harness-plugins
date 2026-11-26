# conventional-commits

Each Claude or Codex session starts with a hint ([prompt.md](prompt.md)): write commit subjects as Conventional
Commits, `type(scope)!: description`, with the types and the revert form that
[conventional-pre-commit](https://github.com/compilerla/conventional-pre-commit) accepts. The check itself is that
hook, which [prek](https://github.com/j178/prek) runs at each commit of the repository, by an agent or by hand.

## Install

Install and enable the plugin as the [root README](../../README.md#install) says. Then, in each repository to check,
add the hook to `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/compilerla/conventional-pre-commit
    rev: v4.5.0
    hooks:
      - id: conventional-pre-commit
        stages: [commit-msg]
```

and install its Git hook: `prek install --hook-type commit-msg`. prek refuses while `core.hooksPath` is set in the
user's or the system's Git config, and says how to go on.

## What the check accepts

With no `args`, conventional-pre-commit takes a subject with one of the types `build`, `chore`, `ci`, `docs`,
`feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test` (in any case), an optional scope, an optional `!`, a
colon and a description; a body only after a blank line. Subjects that start with `Merge` pass, and so do `fixup!`,
`squash!` and `amend!` ones. The subject Git writes for a revert, `Revert "..."`, is refused: the hint asks for
`revert: <the reverted subject>`. `args` in the config change the types and the scopes (see its README).

## What the host needs

- `jq` for the hook: `mise use -g jq`.
- `prek` for the check: `mise use -g prek`.
