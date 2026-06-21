#!/usr/bin/env bash
# skills-lock-autoinstall — restore agent skills from an npx skills lock file.
# Fires on session start. No-op when the project has no skills-lock.json, so it
# is safe to enable globally. Restore is idempotent and runs non-interactively.
set -euo pipefail

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -f "$dir/skills-lock.json" ] || exit 0

cd "$dir"

# `experimental_install` restores exactly what skills-lock.json pins and detects
# the calling agent, installing without prompts. Stay silent and never fail the
# session — a missing npx or a network blip should not block startup.
npx --yes skills experimental_install >/dev/null 2>&1 || true

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
