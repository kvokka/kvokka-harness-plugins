Your prompt cache lives {ttl} minutes from your last model request. After a longer silence the next request pays for
your whole context again, at over ten times the price of a cached read.

- No single wait is longer than {slice} minutes. What may take longer (a subagent, a build, a test run, a watcher)
  runs in the background, and you check on it in time: each check is a model request and renews the cache.
- A check is small: one line of status, not the log.
- After {limit} minutes of waiting on one thing the checks cost more than the cache is worth: wait for it to end.
