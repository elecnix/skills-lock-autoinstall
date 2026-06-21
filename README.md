# skills-lock-autoinstall

> A **[Claude Code](https://docs.claude.com/en/docs/claude-code) plugin**.

Does one thing: **auto-install agent skills from an
[`npx skills`](https://github.com/vercel-labs/skills) lock file on session
start.** Install it with `claude plugin install` (see below) — it is not an npm
package or a standalone CLI.

If a project has a `skills-lock.json` at its root, this plugin restores the
pinned skills into the project (`npx skills experimental_install`) every time you
start a Claude Code session — so the skill content never has to be committed to
the repo. Commit the lock file; let the plugin materialize the skills.

It is a no-op in projects without a `skills-lock.json`, so it is safe to enable
globally.

## Why

`skills-lock.json` is the `package-lock.json` of agent skills: it pins which
skills a project depends on and where they come from. Vendoring the skill
content into every repo is noisy; this plugin treats skills as dependencies —
commit the lock file, restore on demand.

## Install

```sh
claude plugin marketplace add elecnix/skills-lock-autoinstall
claude plugin install skills-lock-autoinstall@skills-lock-autoinstall
```

Restart Claude Code (or start a new session). On the next `startup`, any
`skills-lock.json` in the project root is restored automatically.

## Usage

In a project, add a skill and commit the lock file (not the content):

```sh
npx skills add vercel-labs/next-skills --skill next-best-practices
echo ".agents/skills/" >> .gitignore   # don't vendor the restored content
git add skills-lock.json
```

Anyone who opens the project with this plugin enabled gets the skill restored on
session start. Verify with `/skills`.

### First-run note

Claude Code indexes a project's `.claude/skills/` at startup, *before* this
hook runs. So the restore is picked up automatically as long as that directory
already exists when the session starts:

- **Second session onward:** auto-loads at startup (the directory now exists
  from the previous restore). No action needed.
- **Very first session in a pristine clone** (no `.claude/skills/` yet): the
  skill is restored to disk but Claude already finished its scan — run
  `/reload-skills` once, or just reopen the session.

To make the **first** session auto-load too, commit an empty marker so the
directory exists at clone time:

```sh
mkdir -p .claude/skills && touch .claude/skills/.gitkeep
git add .claude/skills/.gitkeep
```

With `.claude/skills/` present at startup, the hook fills it and Claude indexes
the restored skill in the same first session.

## What it does (and doesn't)

- Runs a single `SessionStart` (`startup`) hook: `npx skills experimental_install`.
- Mirrors the restored skills into `.claude/skills/` (where Claude Code reads
  them) — `skills` restores into `.agents/skills/` but does not always create
  that link ([vercel-labs/skills#1355](https://github.com/vercel-labs/skills/issues/1355)).
- Silent and non-fatal — a missing `npx` or network blip never blocks startup.
- Does **not** add, remove, or update which skills are pinned — that is the
  `npx skills` CLI's job. This plugin only restores what the lock file already
  declares.

## Requirements

- Node.js / `npx` available on `PATH`.

## License

MIT
