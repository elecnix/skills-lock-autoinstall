# skills-lock-autoinstall

A Claude Code plugin that does one thing: **auto-install agent skills from an
[`npx skills`](https://github.com/vercel-labs/skills) lock file on session
start.**

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

## What it does (and doesn't)

- Runs a single `SessionStart` (`startup`) hook: `npx skills experimental_install`.
- Silent and non-fatal — a missing `npx` or network blip never blocks startup.
- Does **not** add, remove, or update which skills are pinned — that is the
  `npx skills` CLI's job. This plugin only restores what the lock file already
  declares.

## Requirements

- Node.js / `npx` available on `PATH`.

## License

MIT
