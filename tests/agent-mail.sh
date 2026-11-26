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
unset CLAUDE_CODE_SESSION_ID CODEX_THREAD_ID AGENT_MAIL_HOST AGENT_MAIL_TOKEN
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

# Without mcp-agent-mail: the session hears why, it is bound with no name, and its commits are refused; a session
# that never started (no plugin) commits with a warning.
bin=$tmp/bin
mkdir "$bin"
for tool in jq git curl flock setsid; do ln -s "$(command -v "$tool")" "$bin/$tool"; done
out=$(PATH="$bin:/usr/bin:/bin" start lone "$tmp/repo")
case $out in *"Agent Mail is unavailable"*"mise use -g github:Dicklesworthstone/mcp_agent_mail_rust"*) ;;
*) fail "no reason: $out" ;; esac
[ "$(jq -r .name "$state/agents/lone.json")" = "" ] || fail "a failed session has a name"
echo a >a.txt
git add a.txt
git commit -q -m 'feat: outside a session'
echo b >a.txt
git add a.txt
if CLAUDE_CODE_SESSION_ID=lone git commit -q -m 'feat: no mail name' 2>/dev/null; then fail "committed without a name"; fi
out=$(CLAUDE_CODE_SESSION_ID=stranger git commit -q -m 'feat: no plugin' 2>&1) || fail "no plugin: refused: $out"
case $out in *"not coordinated"*) ;; *) fail "no plugin: no warning: $out" ;; esac
git reset -q --hard HEAD^

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
  PATH="$bin:/usr/bin:/bin" start prek-lone "$tmp/prek-work" >/dev/null
  if out=$(CODEX_THREAD_ID=prek-lone git commit -q -m 'feat: no mail name' 2>&1); then fail "prek: committed without a name"; fi
  case $out in *"no Agent Mail name"*) ;; *) fail "prek: no reason: $out" ;; esac
  out=$(CODEX_THREAD_ID=stranger git commit -q -m 'feat: no plugin' 2>&1) || fail "prek: no plugin: refused: $out"
  case $out in *"not coordinated"*) ;; *) fail "prek: no plugin: no warning: $out" ;; esac
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

# A cold start: the MCP entry of .mcp.json starts the server, then relays initialize and tools/list to it; Claude runs
# it with CLAUDE_PLUGIN_ROOT set, Codex in the plugin's directory.
entry=$(jq -r '.mcpServers["agent-mail"] | select(.command == "sh") | .args[1]' "$plugin/.mcp.json")
mcp_input=$(printf '%s\n' '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-06-18",
"capabilities":{},"clientInfo":{"name":"test","version":"0"}}}' | jq -c .
  printf '%s\n' '{"jsonrpc":"2.0","method":"notifications/initialized"}' '{"jsonrpc":"2.0","id":1,"method":"tools/list"}')
for how in claude codex; do
  if [ "$how" = claude ]; then
    out=$(printf '%s\n' "$mcp_input" | CLAUDE_PLUGIN_ROOT=$plugin sh -c "$entry")
  else
    out=$(cd "$plugin" && printf '%s\n' "$mcp_input" | env -u CLAUDE_PLUGIN_ROOT sh -c "$entry")
  fi
  printf '%s\n' "$out" | jq -se 'length == 2 and .[0].result.serverInfo != null and
    (.[1].result.tools | map(.name) | index("macro_start_session"))' >/dev/null ||
    fail "mcp ($how): $(printf '%s' "$out" | head -c 300)"
done

# Two sessions, one in the repository and one in its worktree, both of one T3 thread: one project, two names.
ctx_a=$(T3CODE_THREAD_ID=thread-a start sa "$tmp/repo")
ctx_b=$(T3CODE_THREAD_ID=thread-a start sb "$tmp/wt")
key=$(cd "$tmp/repo/.git" && pwd -P)
name_a=$(jq -r .name "$state/agents/sa.json")
name_b=$(jq -r .name "$state/agents/sb.json")
[ -n "$name_a" ] && [ -n "$name_b" ] && [ "$name_a" != "$name_b" ] || fail "names: $name_a $name_b"
case $ctx_a in *"you are \`$name_a\` in the project \`$key\`"*"thread_id"*"fetch_inbox"*) ;; *) fail "context: $ctx_a" ;; esac
case $ctx_b in *"\`$key\`"*) ;; *) fail "the worktree has another project: $ctx_b" ;; esac
# A session resumed under the same id is the same agent, whatever T3 thread it inherits.
[ "$(T3CODE_THREAD_ID=thread-a start sa "$tmp/repo" >/dev/null && jq -r .name "$state/agents/sa.json")" = "$name_a" ] ||
  fail "a resumed session has another name"
[ ! -e "$state/agents/thread-a.json" ] || fail "T3CODE_THREAD_ID named the binding"

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
CLAUDE_CODE_SESSION_ID=sa git commit -q -m 'fix: change a.txt'

# The end of A's session releases its reservations.
echo '{"hook_event_name":"SessionEnd","session_id":"sa"}' | "$plugin/bin/agent-mail" session-end
cd "$tmp/wt"
git add a.txt
CODEX_THREAD_ID=sb git commit -q -m 'fix: take a.txt'
