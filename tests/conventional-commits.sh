#!/bin/sh
# conventional-commits: the session start gives the hint of prompt.md; without jq it names the command that installs it.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)/plugins/conventional-commits
out=$(echo '{"hook_event_name":"SessionStart","session_id":"s"}' | "$root/hooks/session-start")
printf '%s' "$out" | jq -e '.hookSpecificOutput | .hookEventName == "SessionStart" and
  (.additionalContext | test("fix\\(parser\\)") and test("revert: "))' >/dev/null || { echo "no hint: $out"; exit 1; }
tmp=$(mktemp -d)
if out=$(echo '{}' | PATH="$tmp" /bin/sh "$root/hooks/session-start" 2>&1); then echo "ran without jq"; exit 1; fi
case $out in *"mise use -g jq"*) ;; *) echo "no reason: $out"; exit 1 ;; esac
