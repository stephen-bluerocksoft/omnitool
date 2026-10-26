# Review instructions

## What failure looks like here

- A skill tells Claude to do the wrong thing, and every session that loads it does: commit, push, post, or file without an explicit go-ahead; push `HEAD` instead of a named branch; stage with `git add -A` or `git add .`
- A shell snippet in a skill breaks when run: a heredoc nested inside a command substitution, or a command or flag the tool it calls no longer accepts
- A skill contradicts the BRS core standards it runs under, or restates a rule BRS Codex owns, so the two drift apart
- A call into BRS Codex's installed copies breaks: `omni-pr-create` runs `~/.claude/skills/brs-review/scripts/detect-base.sh`

## Severity here

- Any finding in the classes above is Major at least
- Wording, tone, and structure suggestions in prose are Minor at most
- Report at most five Minor findings per review

## Always check

- Every outward action a changed skill takes -- commit, push, `gh`, Slack, email -- sits behind a step that prints what will be sent and waits for the user's selection
- A changed shell snippet was run, or the review says it was not -- `make check` and `make lint` never execute skill code
- A BRS Codex path a skill names still exists in BRS Codex

## Do not report

- What CI already enforces: `make check` (skill frontmatter limits and the rules size ceiling) and `make lint`

## Evidence

- A claim about what a skill makes Claude do cites the `SKILL.md` line that says it, not the skill's description
