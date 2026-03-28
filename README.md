# Omnitool

Personal AI coding toolkit -- commands, workflows, and tools that augment agentic development in Cursor.

Named after the [omni-tool](https://masseffect.fandom.com/wiki/Omni-tool) from Mass Effect: a universal device that does everything.

## Quick Start

```bash
make install
```

This copies commands to `~/.cursor/commands/` and agents to `~/.cursor/agents/` so they are available globally in Cursor.

## Commands

| Command | Description |
| ------- | ----------- |
| `/omni.spec.create` | Create spec artifacts for a feature using the spec-first workflow |
| `/omni.spec.implement` | Implement a feature from its spec with post-implementation verification |
| `/omni.spec.align` | Audit and sync spec artifacts with the actual implementation |
| `/omni.commit` | Checkpoint changes as logically grouped conventional commits (compact-before-PR workflow) |
| `/omni.compact` | Compact a feature branch's noisy commit history into clean, logical commits |
| `/omni.pr.create` | Create a pull request from the current branch using gh CLI |
| `/omni.pr.review` | Comprehensive PR review with inline GitHub comments |
| `/omni.timetrack` | Generate a timetrack entry summarizing work for management |

## Agents

| Agent | Description |
| ----- | ----------- |
| `repo-test-auditor` | Repo-aware test auditor that discovers existing test patterns and validates new tests follow them |

## User Rules

Cursor user rules that apply globally across all projects. Each file in `rules/` is one rule -- paste its contents into **Cursor Settings > General > Rules for AI** as a separate entry.

| Rule | Purpose |
| ---- | ------- |
| `global-defaults` | Conventional commits, Python venv, temp files |
| `spec-first-development` | Speckit workflow, constitution compliance, branch naming |
| `task-management` | Task splitting, completion verification, sub-agent verification |
| `documentation-from-codebase` | Source documentation from code, never fabricate |

## Installation

```bash
# Install commands and agents
make install

# Pull latest and reinstall
make update
```

## Adding a New Command

1. Create `commands/omni.{action}.md` with a `description` in YAML frontmatter
2. Use `$ARGUMENTS` to capture user input
3. Add it to the table above
4. Run `make install`

## Adding a New Agent

1. Create `agents/{name}.md` with `name` and `description` in YAML frontmatter
2. Add it to the agents table above
3. Run `make install`
