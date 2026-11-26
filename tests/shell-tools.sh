#!/bin/sh
# shell-tools: the prompt joins the context of a session and of a subagent.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)/plugins/shell-tools
for event in SessionStart SubagentStart; do
  out=$(printf '{"hook_event_name":"%s","session_id":"s"}' "$event" | "$root/hooks/context")
  [ "$(printf '%s' "$out" | jq -r .hookSpecificOutput.hookEventName)" = "$event" ] || { echo "$out"; exit 1; }
  [ "$(printf '%s' "$out" | jq -r .hookSpecificOutput.additionalContext)" = "$(cat "$root/prompt.md")" ] ||
    { echo "$out"; exit 1; }
done
