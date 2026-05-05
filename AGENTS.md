# AGENTS.md - Omnitool

This file guides AI coding agents working on the Omnitool repository. For human-facing documentation, see [README.md](README.md).

## Project Overview

Omnitool is a personal collection of AI coding tools, skills, agents, and workflows. It installs skills and agents to Cursor for use across all projects.

This is a **content-only repository** -- it contains Markdown files, shell scripts, and a Makefile. There is no application code, no package manager, and no test suite.

Skills follow the open [Agent Skills](https://agentskills.io/) standard. This repository follows the [AGENTS.md](https://agents.md/) open format for agent guidance.

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
  templates/  # Template for new agents (repo-only; not installed by install.sh)
```

## Code Style

- All content files are Markdown (`.md`)
- Shell scripts use `bash` with `set -e` and `set -o pipefail`
- No emojis in any Markdown file
- Follow markdownlint standards
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

1. Copy `templates/agent-template.md` to `agents/{purpose}.md`, remove the introductory lines and the outer fenced block so the file begins with YAML frontmatter (`---`), then replace placeholders. Use lowercase hyphenated filenames; the stem should match `name` in frontmatter
2. Include YAML frontmatter with `name`, `description`, `model`, and `readonly` set explicitly when intent matters
3. Set `model: inherit` (default, uses parent model) or a specific model ID
4. Set `readonly: true` for agents that only read and report (auditors, validators); set `readonly: false` explicitly for agents that create or update files
5. Prefer delegation hints in `description`: use **"Use proactively when..."** when the agent should often be delegated; add scope (tools, branch, layout) when triggers depend on them
6. Update `README.md` to list the new agent
7. Run `make install` to deploy

### Agent configuration fields

| Field | Type | Default | Description |
| ----- | ---- | ------- | ----------- |
| `name` | string | from filename | Display name and identifier (lowercase, hyphens) |
| `description` | string | -- | Short description; parent agents use this to choose delegation |
| `model` | string | `inherit` | `inherit` (parent model) or a specific model ID |
| `readonly` | boolean | `false` | Restricts write permissions (no file edits, no state-changing shell) |
| `is_background` | boolean | `false` | Runs in background without blocking the parent agent |

Cursor honors `readonly` in subagent frontmatter. If you later reuse the same Markdown in another product, check that product's subagent docs for equivalent controls.

## Installation

Skills are copied to `~/.cursor/skills/` and agents to `~/.cursor/agents/` by `scripts/install.sh`. The install is idempotent and safe to run alongside the BRS Codex installer.

## Key concepts

- Open formats: [AGENTS.md](https://agents.md/) (this file) and [Agent Skills](https://agentskills.io/) for all `skills/*/SKILL.md` content.
- **Progressive disclosure** (skills): discovery loads `name`/`description`; keep each `SKILL.md` focused and add `references/` when instructions grow long.

## Do NOT

- Add emojis to any Markdown file
- Place persistent files in `temp/` -- it is gitignored
- Skip updating `README.md` when adding new skills or agents
