# Global Defaults

Universal workflow defaults that apply to every project.

## Conventional Commits

All commit messages MUST use the Conventional Commits format.

Format: `<type>[optional scope]: <description>` (first line 50 chars max, body wraps at 72)

| Type | When to Use |
| ---- | ----------- |
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code change that is neither fix nor feature |
| `test` | Adding or correcting tests |
| `chore` | Other changes (build, CI, tooling) |
| `perf` | Performance improvement |
| `style` | Formatting, no logic change |
| `revert` | Reverts a previous commit |

Use imperative mood ("add" not "added"). Breaking changes: add `!` before colon or `BREAKING CHANGE:` footer.

## Python Environment

Before running Python scripts, check for and activate the project's virtual environment (`.venv/`, `venv/`, or `env/`). Never run Python against the system interpreter when a project venv exists. If no venv is found and one is needed, create it (`python -m venv .venv`) and install dependencies before proceeding.

## Subagent Restriction

Do NOT use the Task tool to parallelize or delegate work to subagents. Execute all steps sequentially in the main agent context. Cursor subagents default to Composer 2, which silently degrades output quality for judgment-intensive work. Built-in Explore and Bash subagents (automatic file browsing and search) are fine -- they only perform mechanical I/O.

## Temporary Files

All throwaway artifacts (scratch scripts, debug output, session notes, work summaries) MUST go in `temp/`. This directory is gitignored.
