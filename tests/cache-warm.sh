#!/bin/sh
# cache-warm: the note joins the context of a session and of a subagent with the cache's lifetime in it; a lifetime
# that is no number of minutes, and a missing jq, fail with a reason.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)/plugins/cache-warm
note() { printf '{"hook_event_name":"%s","session_id":"s"}' "$1" | "$root/hooks/context"; }
for event in SessionStart SubagentStart; do
  out=$(note "$event")
  [ "$(printf '%s' "$out" | jq -r .hookSpecificOutput.hookEventName)" = "$event" ] || { echo "$out"; exit 1; }
  case $out in *"lives 5 minutes"*"longer than 4 minutes"*"After 50 minutes"*) ;; *) echo "$out"; exit 1 ;; esac
done
out=$(CACHE_WARM_TTL=30 note SessionStart)
case $out in *"lives 30 minutes"*"longer than 29 minutes"*"After 300 minutes"*) ;; *) echo "$out"; exit 1 ;; esac
case $out in *'{'[a-z]*'}'*) echo "a placeholder is left: $out"; exit 1 ;; esac
for bad in 5m 1 0; do
  if out=$(CACHE_WARM_TTL=$bad note SessionStart 2>&1); then echo "accepted $bad"; exit 1; fi
done
if out=$(echo '{}' | PATH="$(mktemp -d)" /bin/sh "$root/hooks/context" 2>&1); then echo "ran without jq"; exit 1; fi
case $out in *"mise use -g jq"*) ;; *) echo "no reason: $out"; exit 1 ;; esac
