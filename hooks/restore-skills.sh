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
