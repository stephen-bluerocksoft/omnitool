# Omnitool

Personal AI coding toolkit -- skills, workflows, and tools that augment agentic development in Cursor.

Named after the [omni-tool](https://masseffect.fandom.com/wiki/Omni-tool) from Mass Effect: a universal device that does everything.

## Quick Start

```bash
make install
```

This copies skills to `~/.cursor/skills/` and agents to `~/.cursor/agents/` so they are available globally in Cursor.

## Skills

| Skill | Description |
| ----- | ----------- |
| `omni-spec-create` | Create spec artifacts for a feature using the spec-first workflow |
| `omni-spec-implement` | Implement a feature from its spec with post-implementation verification |
| `omni-plan-implement` | Execute a Cursor Plan Mode plan with verification and proactive test creation |
| `omni-spec-align` | Audit and sync spec artifacts with the actual implementation |
| `omni-commit` | Checkpoint changes as logically grouped conventional commits (compact-before-PR workflow) |
| `omni-compact` | Compact a feature branch's noisy commit history into clean, logical commits |
| `omni-pr-create` | Create a pull request from the current branch using gh CLI |

| `omni-timetrack` | Generate a timetrack entry summarizing work for management |

## Agents

No agents currently shipped -- `repo-test-auditor` was consolidated into the BRS Codex `test-auditor`.

## User Rules

Cursor user rules that apply globally across all projects. Each file in `rules/` is one rule -- paste its contents into **Cursor Settings > General > Rules for AI** as a separate entry.

| Rule | Purpose |
| ---- | ------- |
| `global-defaults` | Conventional commits, Python venv, temp files |
| `spec-first-development` | Speckit workflow, constitution compliance, branch naming |
| `task-management` | Task splitting, completion verification, sub-agent verification |
| `documentation-standards` | Source documentation from code, never fabricate |

## Installation

```bash
# Install skills and agents
make install

# Pull latest and reinstall
make update
```

## Adding a New Skill

1. Create `skills/{name}/SKILL.md` with `name`, `description`, and `disable-model-invocation: true` in YAML frontmatter
2. Add skill instructions
3. Add it to the table above
4. Run `make install`

## Adding a New Agent

1. Start from [`templates/agent-template.md`](templates/agent-template.md): copy it to `agents/{name}.md`, remove the introductory wrapper and outer fenced block so the file begins with YAML frontmatter, then fill in `name`, `description`, and optionally `model`, `readonly`
2. Set `readonly: true` for agents that only read and report (auditors, validators); set `readonly: false` explicitly when the agent writes files or runs state-changing commands
3. Add it to the agents table above
4. Run `make install`

See [AGENTS.md](AGENTS.md) for field reference and conventions.
