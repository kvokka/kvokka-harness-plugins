#!/bin/sh
# conventional-commits: the session start writes the stable gitconfig, and Git then checks every commit's subject,
# beside the repository's own commit-msg hook.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)/plugins/conventional-commits
tmp=$(mktemp -d)
export HOME="$tmp/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.org GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.org
mkdir -p "$HOME"
out=$(echo '{"hook_event_name":"SessionStart","session_id":"s"}' | "$root/hooks/session-start")
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | test("fix\\(parser\\)")' >/dev/null ||
  { echo "no hint: $out"; exit 1; }
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=include.path
export GIT_CONFIG_VALUE_0="$HOME/.local/state/kvokka-harness-plugins/conventional-commits/gitconfig"
git init -q "$tmp/work"
cd "$tmp/work"
printf '#!/bin/sh\ntouch .git/local-hook-ran\n' >.git/hooks/commit-msg
chmod +x .git/hooks/commit-msg
commit() { git commit -q --allow-empty -m "$1"; }
reject() { if commit "$1" 2>/dev/null; then echo "accepted: $1"; exit 1; fi; }
commit 'docs: describe the parser'
test -f .git/local-hook-ran
commit 'feat(api)!: change the response'
reject 'update docs'
reject 'Fix: capital type'
reject 'fix:  two spaces'
reject 'fix(a b): space in the scope'
[ "$(git rev-list --count HEAD)" = 2 ]
