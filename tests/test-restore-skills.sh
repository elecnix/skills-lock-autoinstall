#!/usr/bin/env bash
# The restore hook must leave skills-lock.json byte for byte as it was.
#
# `skills experimental_install` has no frozen mode. A source that serves only its
# current content is refetched, and the CLI writes the new hashes into the lock.
# This test replaces `npx` with a stub that does the same, then runs the hook.
set -uo pipefail

hook="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks/restore-skills.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
check() { # check <name> <command...>: passes when the command succeeds
  local name="$1"
  shift
  if "$@"; then echo "ok   $name"; else echo "FAIL $name"; fail=1; fi
}
lock_is_pinned() { [ "$(cat "$tmp/project/skills-lock.json")" = "$lock" ]; }
run_hook() {
  PATH="$tmp/bin:$PATH" CLAUDE_PROJECT_DIR="$tmp/project" bash "$hook" >"$tmp/out"
}

mkdir -p "$tmp/bin" "$tmp/project"
cat >"$tmp/bin/npx" <<'STUB'
#!/usr/bin/env bash
printf '{"version":1,"skills":{"drifted":true}}\n' >skills-lock.json
mkdir -p .agents/skills/example
exit "${STUB_EXIT:-0}"
STUB
chmod +x "$tmp/bin/npx"

lock='{"version":1,"skills":{"pinned":true}}'
printf '%s\n' "$lock" >"$tmp/project/skills-lock.json"

check "the hook exits 0" run_hook
check "restores the skills" test -d "$tmp/project/.agents/skills/example"
check "leaves skills-lock.json byte-identical" lock_is_pinned
check "still links the restored skill for Claude Code" test -L "$tmp/project/.claude/skills/example"
check "still asks Claude Code to reload skills" grep -q reloadSkills "$tmp/out"

STUB_EXIT=3 run_hook
check "the hook never fails the session" test "$?" -eq 0
check "restores the lock when the install fails" lock_is_pinned

mkdir -p "$tmp/empty"
(cd "$tmp/empty" && PATH="$tmp/bin:$PATH" CLAUDE_PROJECT_DIR="$tmp/empty" bash "$hook")
check "does nothing without a lock" test ! -e "$tmp/empty/skills-lock.json" -a ! -d "$tmp/empty/.agents"

# Live re-sync (issue #1): SessionStart registers the lock as a watched path and a
# FileChanged run restores again, without looping on its own writes.
check "watches the lock for changes" grep -q "\"watchPaths\":\\[\"$tmp/project/skills-lock.json\"\\]" "$tmp/out"

cat >"$tmp/bin/npx" <<'STUB'
#!/usr/bin/env bash
printf 'x\n' >>"$STUB_COUNT"
printf '{"version":1,"skills":{"drifted":true}}\n' >skills-lock.json
mkdir -p ".agents/skills/${STUB_SKILL:-example}"
STUB
export STUB_COUNT="$tmp/count"
: >"$STUB_COUNT"
runs() { wc -l <"$STUB_COUNT" | tr -d ' '; }
run_watch() {
  PATH="$tmp/bin:$PATH" CLAUDE_PROJECT_DIR="$tmp/project" bash "$hook" watch >"$tmp/out"
}

run_hook # SessionStart: restores and records the lock it restored
before="$(runs)"
run_watch # the hook's own write-back of the lock
check "ignores a change that matches the last restore" test "$(runs)" -eq "$before"
check "stays silent when it skips" test ! -s "$tmp/out"

lock='{"version":1,"skills":{"pinned":true,"added":true}}'
printf '%s\n' "$lock" >"$tmp/project/skills-lock.json"
STUB_SKILL=added run_watch
check "restores again when the lock is edited" test "$(runs)" -eq $((before + 1))
check "links the newly restored skill" test -L "$tmp/project/.claude/skills/added"
check "keeps the edited lock byte-identical" lock_is_pinned
check "asks Claude Code to reload skills after an edit" grep -q reloadSkills "$tmp/out"
run_watch
check "does not loop on the edited lock" test "$(runs)" -eq $((before + 1))

exit "$fail"
