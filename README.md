# Omnitool

Personal AI coding toolkit -- skills, workflows, and tools that augment agentic development. Built Claude-first (Claude Code), with Cursor supported as a secondary target.

Named after the [omni-tool](https://masseffect.fandom.com/wiki/Omni-tool) from Mass Effect: a universal device that does everything.

## Quick Start

```bash
make install
```

This copies skills and agents to both `~/.claude/` (Claude Code) and `~/.cursor/` (Cursor) so they are available globally in each. Skills follow the open [Agent Skills](https://agentskills.io/) standard and run in both tools; where a step depends on tool-specific paths or commands, the skill body handles both.

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

Global rules that apply across all projects. Each file in `rules/` is one rule. These are not copied by `make install` -- install them into each tool's always-on layer by hand:

- **Claude Code**: append the rule text to `~/.claude/CLAUDE.md` (or import it), which loads every session.
- **Cursor**: paste the rule contents into **Cursor Settings > General > Rules for AI** as a separate entry.

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

1. Create `skills/{name}/SKILL.md` with `name` and a trigger-rich `description` in YAML frontmatter
2. Decide invocation: omit `disable-model-invocation` for reference/lightweight skills so the model auto-invokes them by `description`; add `disable-model-invocation: true` for heavy, side-effecting workflows (branch creation, PR posting, multi-file scaffolds) that should stay slash-command-only
3. Add skill instructions; where a step is tool-specific, cover both Claude Code and Cursor in the body
4. Add it to the table above
5. Run `make install`

## Adding a New Agent

1. Start from [`templates/agent-template.md`](templates/agent-template.md): copy it to `agents/{name}.md`, remove the introductory wrapper and outer fenced block so the file begins with YAML frontmatter, then fill in `name`, `description`, and optionally `model`, `readonly`
2. Set `readonly: true` for agents that only read and report (auditors, validators); set `readonly: false` explicitly when the agent writes files or runs state-changing commands
3. Add it to the agents table above
4. Run `make install`

See [AGENTS.md](AGENTS.md) for field reference and conventions.
