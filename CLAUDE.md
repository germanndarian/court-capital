@AGENTS.md

# Court & Capital: Claude workflow

Before starting, read the project note in the maintainer's personal OS:
`~/Documents/Projects/personal-os/projects/Court & Capital/Court & Capital.md`.
It has the current state, what's next, and the rules and decisions. The ideas
list (`Court & Capital ideas.md`) is in the same folder. New docs go there too,
not into the repo: this repo keeps only README.md, CLAUDE.md, AGENTS.md and
`.claude/skills/`. Leave the sections marked `<!-- auto -->` alone, because the
sync agent rewrites them from commits.

How the app works and the setup are in README.md.

## Pull requests

Work on a branch and open a PR; nothing merges without the maintainer's okay
for that PR. No Claude co-author or "Generated with" lines in commits or PRs.

Keep the description short:
- Up to three bullets: what changed, in plain words.
- **Checked:** one line: the tests and build that ran, and anything looked at
  by hand.
- **For you:** one line, only when the maintainer has to do something.
- **Open:** one line, only when something is unfinished or not checked.

Nothing else: no why, no how it works, no step-by-step test plan.
