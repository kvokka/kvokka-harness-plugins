Write commit subjects as Conventional Commits: `type(scope)!: description`, e.g. `fix(parser): handle empty input`.
The type is one of build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test; the scope and `!` are
optional. A body comes after a blank line. A revert's subject is `revert: <the reverted subject>`, not Git's
`Revert "..."`.
