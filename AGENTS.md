# AGENTS.md - Omnitool

This file guides AI coding agents working on the Omnitool repository.

## Project Overview

Omnitool is a personal collection of AI coding tools, commands, and workflows. It installs slash commands to Cursor for use across all projects.

This is a **content-only repository** -- it contains Markdown files, shell scripts, and a Makefile. There is no application code, no package manager, and no test suite.

## Setup Commands

- Install globally: `make install`
- Pull latest and reinstall: `make update`
- View all targets: `make help`

## Directory Structure

```text
omnitool/
  commands/   # Slash commands (installed to ~/.cursor/commands/)
  scripts/    # Installation scripts
```

## Code Style

- All content files are Markdown (`.md`)
- Shell scripts use `bash` with `set -e` and `set -o pipefail`
- No emojis in any Markdown file
- Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
- Commit subject line must be 50 characters or less, body wraps at 72

## Naming Conventions

| Content Type | Pattern | Example |
| ------------ | ------- | ------- |
| Commands | `omni.{action}.md` | `omni.commit.md` |

## Creating New Commands

1. Create `commands/omni.{action}.md`
2. Include YAML frontmatter with `description`
3. Use `$ARGUMENTS` for user input capture
4. Update `README.md` to list the new command
5. Run `make install` to deploy

## Installation

Commands are copied to `~/.cursor/commands/` by `scripts/install.sh`. The install is idempotent and safe to run alongside the BRS Codex installer.

## Do NOT

- Add emojis to any Markdown file
- Place persistent files in `temp/` -- it is gitignored
- Skip updating `README.md` when adding new commands
