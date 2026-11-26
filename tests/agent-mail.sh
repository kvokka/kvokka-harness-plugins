#!/bin/sh
# agent-mail: the refusals that need no server always, and with prek on the PATH the hook of .pre-commit-hooks.yaml
# through prek; with mcp-agent-mail on the PATH, two sessions of one repository (one in a worktree) against a real
# server: their identities, a refused commit of a held path, and the release.
set -eu
repo=$(cd "$(dirname "$0")/.." && pwd)
plugin=$repo/plugins/agent-mail
tmp=$(mktemp -d)
export HOME="$tmp/home" PREK_HOME="$tmp/prek" XDG_CONFIG_HOME="$tmp/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.org GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.org
export AGENT_MAIL_PORT=$((20000 + $$ % 20000))
unset T3CODE_THREAD_ID CLAUDE_CODE_SESSION_ID CODEX_THREAD_ID AGENT_MAIL_HOST AGENT_MAIL_TOKEN
state=$HOME/.local/state/kvokka-harness-plugins/agent-mail
mkdir -p "$HOME"
fail() { echo "$*"; exit 1; }
start() { jq -nc --arg s "$1" --arg cwd "$2" '{hook_event_name: "SessionStart", session_id: $s, cwd: $cwd, model: "m"}' |
  "$plugin/bin/agent-mail" session-start | jq -r .hookSpecificOutput.additionalContext; }

git init -q "$tmp/repo"
cd "$tmp/repo"
git commit -q --allow-empty -m 'chore: start'
git worktree add -q "$tmp/wt" 2>/dev/null
# The repository's pre-commit hook runs the check, as the hook of .pre-commit-hooks.yaml does.
mkdir "$tmp/hooks"
printf '#!/bin/sh\nexec "%s/bin/agent-mail" pre-commit\n' "$plugin" >"$tmp/hooks/pre-commit"
chmod +x "$tmp/hooks/pre-commit"
git config core.hooksPath "$tmp/hooks"

# A non-loopback host without a token: no server.
out=$(AGENT_MAIL_HOST=0.0.0.0 "$plugin/bin/agent-mail-up" 2>&1) && fail "started without a token"
case $out in *"not loopback"*) ;; *) fail "no reason: $out" ;; esac

# Without mcp-agent-mail: the session hears why, and its commits are refused.
bin=$tmp/bin
mkdir "$bin"
for tool in jq git curl flock setsid; do ln -s "$(command -v "$tool")" "$bin/$tool"; done
out=$(PATH="$bin:/usr/bin:/bin" start lone "$tmp/repo")
case $out in *"Agent Mail is unavailable"*"mise use -g github:Dicklesworthstone/mcp_agent_mail_rust"*) ;;
*) fail "no reason: $out" ;; esac
echo a >a.txt
git add a.txt
git commit -q -m 'feat: outside a session'
echo b >a.txt
git add a.txt
if CLAUDE_CODE_SESSION_ID=lone git commit -q -m 'feat: no mail name' 2>/dev/null; then fail "committed without a name"; fi
git reset -q --hard

# Without jq the check names the command that installs it.
nojq=$tmp/nojq
mkdir "$nojq"
ln -s "$(command -v git)" "$nojq/git"
out=$(CLAUDE_CODE_SESSION_ID=lone PATH="$nojq:/usr/bin:/bin" "$plugin/bin/agent-mail" pre-commit 2>&1) && fail "passed without jq"
case $out in *"mise use -g jq"*) ;; *) [ -x /usr/bin/jq ] || fail "no reason: $out" ;; esac

# Through prek: the hook of this repository's .pre-commit-hooks.yaml, from a copy of the working tree.
if command -v prek >/dev/null; then
  git init -q "$tmp/hook-repo"
  mkdir -p "$tmp/hook-repo/plugins"
  cp "$repo/.pre-commit-hooks.yaml" "$tmp/hook-repo/"
  cp -R "$plugin" "$tmp/hook-repo/plugins/"
  git -C "$tmp/hook-repo" add -A
  git -C "$tmp/hook-repo" commit -q -m 'chore: the hooks'
  git init -q "$tmp/prek-work"
  cd "$tmp/prek-work"
  printf 'repos:\n  - repo: %s\n    rev: %s\n    hooks:\n      - id: agent-mail-reservations\n' \
    "$tmp/hook-repo" "$(git -C "$tmp/hook-repo" rev-parse HEAD)" >.pre-commit-config.yaml
  prek install -q >/dev/null
  git add -A
  git commit -q -m 'feat: outside a session' >/dev/null 2>&1
  echo a >a.txt
  git add a.txt
  if out=$(CODEX_THREAD_ID=lone git commit -q -m 'feat: no mail name' 2>&1); then fail "prek: committed without a name"; fi
  case $out in *"no Agent Mail name"*) ;; *) fail "prek: no reason: $out" ;; esac
  cd "$tmp/repo"
else
  echo "prek is not on the PATH: the check through prek is skipped"
fi

if ! command -v mcp-agent-mail >/dev/null; then
  echo "mcp-agent-mail is not on the PATH: the server part is skipped"
  exit 0
fi
# The supervisor leads its own process group, the server's too.
stop() { pgid=$(pgrep -f "supervisor-$AGENT_MAIL_PORT.lock" || true); [ -z "$pgid" ] || kill -- "-$pgid"; }
trap stop EXIT

# Two sessions, one in the repository and one in its worktree: one project, two names.
ctx_a=$(T3CODE_THREAD_ID=thread-a start sa "$tmp/repo")
ctx_b=$(start sb "$tmp/wt")
key=$(cd "$tmp/repo/.git" && pwd -P)
name_a=$(jq -r .name "$state/agents/thread-a.json")
name_b=$(jq -r .name "$state/agents/sb.json")
[ -n "$name_a" ] && [ -n "$name_b" ] && [ "$name_a" != "$name_b" ] || fail "names: $name_a $name_b"
case $ctx_a in *"you are \`$name_a\` in the project \`$key\`"*"thread_id"*"fetch_inbox"*) ;; *) fail "context: $ctx_a" ;; esac
case $ctx_b in *"\`$key\`"*) ;; *) fail "the worktree has another project: $ctx_b" ;; esac
[ "$(T3CODE_THREAD_ID=thread-a start other "$tmp/repo" >/dev/null && jq -r .name "$state/agents/thread-a.json")" = "$name_a" ] ||
  fail "a thread's second session has another name"

# A holds a.txt: B's commit of it is refused, of another path it goes; A's own commit goes.
jq -nc --arg k "$key" --arg n "$name_a" '{jsonrpc: "2.0", id: 1, method: "tools/call", params: {name: "file_reservation_paths",
  arguments: {project_key: $k, agent_name: $n, paths: ["a.txt"], exclusive: true, ttl_seconds: 600}}}' |
  curl -fsS -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' --data-binary @- \
    "http://127.0.0.1:$AGENT_MAIL_PORT/mcp/" | grep -q granted || fail "no reservation"
cd "$tmp/wt"
echo b >a.txt
git add a.txt
head=$(git rev-parse HEAD)
if out=$(CODEX_THREAD_ID=sb git commit -q -m 'fix: take a.txt' 2>&1); then fail "committed a held path"; fi
case $out in *"a.txt: reserved by $name_a"*) ;; *) fail "no holder: $out" ;; esac
[ "$(git rev-parse HEAD)" = "$head" ] || fail "HEAD moved"
git reset -q a.txt
echo b >b.txt
git add b.txt
CODEX_THREAD_ID=sb git commit -q -m 'feat: add b.txt'
cd "$tmp/repo"
echo c >a.txt
git add a.txt
T3CODE_THREAD_ID=thread-a git commit -q -m 'fix: change a.txt'

# The end of A's session releases its reservations.
echo '{"hook_event_name":"SessionEnd","session_id":"sa"}' | T3CODE_THREAD_ID=thread-a "$plugin/bin/agent-mail" session-end
cd "$tmp/wt"
git add a.txt
CODEX_THREAD_ID=sb git commit -q -m 'fix: take a.txt'
