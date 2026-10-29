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

exit "$fail"
