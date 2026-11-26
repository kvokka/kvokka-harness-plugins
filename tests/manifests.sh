#!/bin/sh
# Manifests: each plugin has both manifests with one name and version, both marketplaces list exactly the plugins,
# and the changelog has the plugin's current version.
set -eu
cd "$(dirname "$0")/.."
fail() { echo "$*"; exit 1; }
dirs=$(find plugins -mindepth 1 -maxdepth 1 -type d | sed 's|^plugins/||' | sort)
[ "$(jq -r '.plugins[] | "\(.name) \(.source)"' .claude-plugin/marketplace.json | sort)" = \
  "$(for p in $dirs; do echo "$p ./plugins/$p"; done)" ] || fail "the Claude marketplace does not list plugins/*"
[ "$(jq -r '.plugins[] | "\(.name) \(.source.path)"' .agents/plugins/marketplace.json | sort)" = \
  "$(for p in $dirs; do echo "$p ./plugins/$p"; done)" ] || fail "the Codex marketplace does not list plugins/*"
for p in $dirs; do
  claude=$(jq -r '"\(.name) \(.version)"' "plugins/$p/.claude-plugin/plugin.json")
  codex=$(jq -r '"\(.name) \(.version)"' "plugins/$p/.codex-plugin/plugin.json")
  [ "$claude" = "$codex" ] || fail "$p: the manifests differ: $claude / $codex"
  [ "$claude" = "$p ${claude#* }" ] || fail "$p: the manifest names $claude"
  jq -e '.interface.displayName | strings' "plugins/$p/.codex-plugin/plugin.json" >/dev/null ||
    fail "$p: the Codex manifest has no interface.displayName"
  awk -v p="## $p" -v v="### ${claude#* }" '$0 == p {s = 1; next} /^## / {s = 0} s && $0 == v {f = 1} END {exit !f}' \
    CHANGELOG.md || fail "$p: CHANGELOG.md has no section for ${claude#* }"
  [ -f "plugins/$p/README.md" ] || fail "$p: no README.md"
  [ ! -f "plugins/$p/hooks/hooks.json" ] || jq -e .hooks "plugins/$p/hooks/hooks.json" >/dev/null ||
    fail "$p: hooks/hooks.json has no hooks"
done
