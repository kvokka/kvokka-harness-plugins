#!/bin/sh
# dcg: the guard hands the hook input to dcg, and refuses every command when dcg is missing.
set -eu
guard=$(cd "$(dirname "$0")/.." && pwd)/plugins/dcg/hooks/guard
bin=$(mktemp -d)
input='{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}'

# Without dcg: exit 2 and a reason.
out=$(printf '%s' "$input" | PATH="$bin:/usr/bin:/bin" "$guard" 2>&1) && exit 1
case $out in *"not on the PATH"*) ;; *) echo "no reason: $out"; exit 1 ;; esac

# With dcg: it gets the input on stdin and its answer is the hook's.
printf '#!/bin/sh\necho "dcg saw: $(cat)"\n' >"$bin/dcg"
chmod +x "$bin/dcg"
out=$(printf '%s' "$input" | PATH="$bin:/usr/bin:/bin" "$guard")
[ "$out" = "dcg saw: $input" ] || { echo "unexpected: $out"; exit 1; }
