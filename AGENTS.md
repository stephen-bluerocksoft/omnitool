# AGENTS.md - Omnitool

This file guides AI coding agents working on the Omnitool repository.

## Project Overview

Omnitool is a personal collection of AI coding tools, skills, agents, and workflows. It installs skills and agents to Cursor for use across all projects.

This is a **content-only repository** -- it contains Markdown files, shell scripts, and a Makefile. There is no application code, no package manager, and no test suite.

## Setup Commands

- Install globally: `make install`
- Pull latest and reinstall: `make update`
- View all targets: `make help`

## Directory Structure

```text
omnitool/
  agents/     # Subagent definitions (installed to ~/.cursor/agents/)
  skills/     # Skill directories ({name}/SKILL.md, installed globally)
  rules/      # User rules (paste into Cursor Settings > General > Rules for AI)
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
| Skills | `{name}/SKILL.md` within `skills/` | `omni-commit/SKILL.md` |
| Agents | `{purpose}.md` | `repo-test-auditor.md` |

## Creating New Skills

1. Create `skills/{name}/SKILL.md`
2. Include YAML frontmatter with `name`, `description`, and `disable-model-invocation: true`
3. Add skill instructions
4. Update `README.md` to list the new skill
5. Run `make install` to deploy

## Creating New Agents

1. Create `agents/{purpose}.md`
2. Include YAML frontmatter with `name`, `description`, and optionally `model` and `readonly`
3. Set `model: inherit` (default, uses parent model) or a specific model ID
4. Set `readonly: true` for agents that only read and report
5. Update `README.md` to list the new agent
6. Run `make install` to deploy

## Installation

Skills are copied to `~/.cursor/skills/` and agents to `~/.cursor/agents/` by `scripts/install.sh`. The install is idempotent and safe to run alongside the BRS Codex installer.

## Do NOT

- Add emojis to any Markdown file
- Place persistent files in `temp/` -- it is gitignored
- Skip updating `README.md` when adding new skills or agents
