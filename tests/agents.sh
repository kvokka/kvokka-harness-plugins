#!/bin/sh
# agents: the note names the cheaper models of the session's harness; the Claude subagent loads the expert skill.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)/plugins/agents
note() { printf '{"hook_event_name":"SessionStart","session_id":"s"}' | "$root/hooks/context"; }
out=$(note)
[ "$(printf '%s' "$out" | jq -r .hookSpecificOutput.hookEventName)" = SessionStart ] || { echo "$out"; exit 1; }
case $out in *"subagent: sonnet, haiku, the cheapest last"*) ;; *) echo "$out"; exit 1 ;; esac
out=$(AGENTS_CHEAP_MODELS="gpt-6.1-terra, gpt-6-luna" note)
case $out in *"subagent: gpt-6.1-terra, gpt-6-luna, the cheapest last"*) ;; *) echo "$out"; exit 1 ;; esac
if out=$(echo '{}' | PATH="$(mktemp -d)" /bin/sh "$root/hooks/context" 2>&1); then echo "ran without jq"; exit 1; fi
case $out in *"mise use -g jq"*) ;; *) echo "no reason: $out"; exit 1 ;; esac
# The subagent's text is the skill: its definition names a skill this plugin has.
skill=$(sed -n '/^skills:$/,/^[a-z-]*:/s/^  - //p' "$root/agents/expert.md")
[ -f "$root/skills/$skill/SKILL.md" ] || { echo "agents/expert.md names no skill of the plugin: $skill"; exit 1; }
