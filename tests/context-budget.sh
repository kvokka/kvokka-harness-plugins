#!/bin/sh
# context-budget: the budget note, the denied subagent, the stop with its dump, on Claude and Codex inputs.
set -eu
budget=$(cd "$(dirname "$0")/.." && pwd)/plugins/context-budget/hooks/budget
tmp=$(mktemp -d)
export CLAUDE_PLUGIN_DATA="$tmp/data" CONTEXT_BUDGET_SOFT=1000 CONTEXT_BUDGET_HARD=2000 CONTEXT_BUDGET_STEP=100
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.org GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.org
git init -q "$tmp/work"
git -C "$tmp/work" commit -q --allow-empty -m 'chore: start'
fail() { echo "$*"; exit 1; }
# hook <event> <session> [<extra JSON fields>]: the hook's answer for a Claude input (Codex: a turn_id in the extra).
hook() {
  jq -nc --arg e "$1" --arg s "$2" --arg t "$tmp/$2.jsonl" --arg cwd "$tmp/work" --argjson x "${3:-{\}}" \
    '{hook_event_name: $e, session_id: $s, transcript_path: $t, cwd: $cwd} + $x' | "$budget"
}
claude_usage() {
  jq -nc --argjson n "$1" '{type: "assistant", message: {model: "m", content: [{type: "text", text: "working"}],
    usage: {input_tokens: $n, cache_creation_input_tokens: 0, cache_read_input_tokens: 0, output_tokens: 0}}}' >>"$tmp/$2.jsonl"
}
codex_usage() {
  jq -nc --argjson n "$1" '{type: "event_msg", payload: {type: "token_count", info: {last_token_usage: {total_tokens: $n}}}}' \
    >>"$tmp/$2.jsonl"
}
ctx() { printf '%s' "$1" | jq -r '.hookSpecificOutput.additionalContext // empty'; }

# Claude: the start removes week-old files, names the budget and keeps the commit the session starts on.
mkdir -p "$tmp/data"
touch -d '8 days ago' "$tmp/data/old.md"
touch "$tmp/data/new.md"
case $(ctx "$(hook SessionStart c)") in *"budget is 1k tokens"*) ;; *) fail "no budget at the start" ;; esac
[ "$(cat "$tmp/data/c.base")" = "$(git -C "$tmp/work" rev-parse HEAD)" ] || fail "no base"
[ ! -e "$tmp/data/old.md" ] && [ -e "$tmp/data/new.md" ] || fail "the prune of old files"
claude_usage 500 c
[ -z "$(hook PostToolUse c)" ] || fail "a note under the budget"
[ -z "$(hook PreToolUse c '{"tool_name":"Agent"}')" ] || fail "a subagent denied under the budget"
claude_usage 1200 c
case $(ctx "$(hook PostToolUse c)") in *"past your budget of 1k"*"final answer"*) ;; *) fail "no wrap-up note" ;; esac
claude_usage 1250 c
[ -z "$(hook PostToolUse c)" ] || fail "a note before the step"
claude_usage 1300 c
[ -n "$(ctx "$(hook PostToolUse c)")" ] || fail "no note after the step"
out=$(hook PreToolUse c '{"tool_name":"Task"}')
[ "$(printf '%s' "$out" | jq -r .hookSpecificOutput.permissionDecision)" = deny ] || fail "a subagent allowed: $out"
[ -z "$(hook PreToolUse c '{"tool_name":"Bash"}')" ] || fail "a shell command denied past soft"
[ -z "$(hook PreCompact c)" ] || fail "an answer to compaction below hard"

# A Claude subagent: its own transcript, its own note.
mkdir -p "$tmp/c/subagents"
jq -nc '{type: "assistant", message: {model: "m", usage: {input_tokens: 1100}}}' >"$tmp/c/subagents/agent-a1.jsonl"
case $(ctx "$(hook PostToolUse c '{"agent_id":"a1"}')") in *"to your caller"*) ;; *) fail "no subagent note" ;; esac

# Claude past hard: the turn ends, the dump is written once, and every later call is denied.
claude_usage 2100 c
out=$(hook PreToolUse c '{"tool_name":"Bash"}')
printf '%s' "$out" | jq -e --arg d "$tmp/data/c.md" '.continue == false and
  .hookSpecificOutput.permissionDecision == "deny" and (.stopReason | contains($d))' >/dev/null || fail "no stop: $out"
grep -q '^## git log' "$tmp/data/c.md" || fail "no git state in the dump"
grep -q 'working' "$tmp/data/c.md" || fail "no last text in the dump"
claude_usage 10 c
[ "$(printf '%s' "$(hook PreToolUse c '{"tool_name":"Bash"}')" | jq -r .hookSpecificOutput.permissionDecision)" = deny ] ||
  fail "a call after the stop"
out=$(hook PreToolUse c '{"tool_name":"Bash","agent_id":"a1"}')
printf '%s' "$out" | jq -e --arg d "$tmp/data/c.md" '.hookSpecificOutput.permissionDecisionReason | contains($d)' \
  >/dev/null || fail "a subagent of a stopped session: $out"

# Codex: no continue on PreToolUse, and an attempt to compact stops the session.
turn='{"turn_id":"t1","tool_name":"spawn_agent"}'
codex_usage 1100 x
out=$(hook PreToolUse x "$turn")
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny" and
  (.hookSpecificOutput.permissionDecisionReason | length > 0) and (has("continue") | not)' >/dev/null || fail "codex: $out"
[ -z "$(hook PreCompact x '{"turn_id":"t1"}')" ] || fail "codex: an answer to compaction below hard"
[ ! -f "$tmp/data/x.md" ] || fail "codex: a dump below hard"
codex_usage 2100 x
out=$(hook PreCompact x '{"turn_id":"t1"}')
printf '%s' "$out" | jq -e '.continue == false and (has("decision") | not)' >/dev/null || fail "codex compacts: $out"
[ -f "$tmp/data/x.md" ] || fail "codex: no dump"
out=$(hook PreToolUse x '{"turn_id":"t1","tool_name":"Bash"}')
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny" and (has("continue") | not)' >/dev/null ||
  fail "codex after the stop: $out"
