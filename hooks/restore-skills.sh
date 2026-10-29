#!/usr/bin/env bash
# skills-lock-autoinstall — restore agent skills from an npx skills lock file.
# Fires on session start, and again as `restore-skills.sh watch` when a
# FileChanged hook sees skills-lock.json change mid-session. No-op when the
# project has no skills-lock.json, so it is safe to enable globally. Restore is
# idempotent and runs non-interactively.
set -euo pipefail

mode="${1:-start}"

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -f "$dir/skills-lock.json" ] || exit 0

cd "$dir"

# The restore puts the lock back on exit, and that write is itself a change the
# watcher reports. Record the hash of the lock we last restored from and skip a
# watch event that carries the same content, or each restore would trigger the
# next one forever.
stamp="$dir/.agents/.skills-lock-restored"
lock_hash() { shasum -a 256 skills-lock.json | cut -d' ' -f1; }
if [ "$mode" = watch ] && [ -f "$stamp" ] && [ "$(lock_hash)" = "$(cat "$stamp")" ]; then
  exit 0
fi

# `experimental_install` restores exactly what skills-lock.json pins and detects
# the calling agent, installing without prompts. Stay silent and never fail the
# session — a missing npx or a network blip should not block startup.
#
# The CLI has no frozen mode: a source that serves only its current content is
# refetched, and the new hashes are written into the lock. A restore must never
# change the lock, so put it back on every exit path, including a timeout.
backup="$(mktemp)"
cp skills-lock.json "$backup"
pinned="$(lock_hash)"
# Rewrite the lock only when the CLI changed it: an untouched write would still
# fire the watcher.
trap 'cmp -s "$backup" skills-lock.json || cp "$backup" skills-lock.json; rm -f "$backup"' EXIT
npx --yes skills experimental_install >/dev/null 2>&1 || true
mkdir -p "$dir/.agents"
printf '%s\n' "$pinned" >"$stamp"

# Bridge the restored skills to where Claude Code actually reads them. `skills`
# restores into .agents/skills/ but does not always create the .claude/skills/
# links Claude loads from (vercel-labs/skills#1355). Mirror each restored skill
# as a relative symlink so it is indexed this same session.
if [ -d "$dir/.agents/skills" ]; then
  mkdir -p "$dir/.claude/skills"
  for skill in "$dir/.agents/skills"/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    link="$dir/.claude/skills/$name"
    [ -e "$link" ] || ln -s "../../.agents/skills/$name" "$link"
  done
fi

# Tell Claude Code to re-scan skill/command directories *after* SessionStart
# hooks finish, so a skill we just restored loads in this same first session
# (otherwise it isn't indexed until /reload-skills or the next session). This
# JSON is the only thing we print to stdout — keep all other output silenced.
if [ "$mode" = watch ]; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"FileChanged","reloadSkills":true}}'
else
  # Watch the lock so a mid-session edit re-runs this script via FileChanged.
  # watchPaths must be absolute.
  watched="$(printf '%s' "$dir/skills-lock.json" | sed 's/[\\"]/\\&/g')"
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","reloadSkills":true,"watchPaths":["%s"]}}\n' "$watched"
fi
