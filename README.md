# Omnitool

Personal AI coding toolkit -- skills, workflows, and tools that augment agentic development. Built for Claude Code.

Named after the [omni-tool](https://masseffect.fandom.com/wiki/Omni-tool) from Mass Effect: a universal device that does everything.

## Quick Start

```bash
make install
```

This copies skills and agents into `~/.claude/` and injects the global rules into `~/.claude/CLAUDE.md`, so they are available in every Claude Code session. Skills follow the open [Agent Skills](https://agentskills.io/) standard.

## Skills

| Skill | Description |
| ----- | ----------- |
| `omni-spec-create` | Create spec artifacts for a feature using the spec-first workflow |
| `omni-spec-modify` | Change an existing feature's spec before implementation, cascading edits through the artifacts |
| `omni-spec-implement` | Implement a feature from its spec with post-implementation verification |
| `omni-plan-implement` | Execute an approved plan-mode plan with verification and proactive test creation |
| `omni-spec-align` | Audit and sync spec artifacts with the actual implementation |
| `omni-commit` | Group changes into conventional commits, propose them for approval, and commit what is approved |
| `omni-compact` | Compact a feature branch's noisy commit history into clean, logical commits |
| `omni-pr-create` | Create a pull request from the current branch using gh CLI |
| `omni-pr-address` | Evaluate review feedback on a pull request, implement what holds up, and report back |
| `omni-timetrack` | Generate a timetrack entry summarizing work for management |

## Agents

No agents currently shipped -- `repo-test-auditor` was consolidated into the BRS Codex `test-auditor`.

## User Rules

Global rules that apply across all projects. Each file in `rules/` is one rule. `make install` injects all of them into `~/.claude/CLAUDE.md` between `<!-- OMNITOOL-RULES-START -->` and `<!-- OMNITOOL-RULES-END -->` markers, so they load every session. Re-running the installer replaces that block in place and never touches other content (e.g. a BRS Codex block). To add a rule to the always-on set, drop a file in `rules/` and add its name to `RULES_ORDER` in `scripts/install.sh`.

| Rule | Purpose |
| ---- | ------- |
| `global-defaults` | Conventional commits, Python venv, temp files |
| `commit-proposals` | How to present a commit for approval: grouping, files, what was left out |
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
2. Decide invocation: omit `disable-model-invocation` so the model auto-invokes the skill by `description`. Heavy, side-effecting workflows may still be model-invocable if they open with a mandatory confirmation gate (see `omni-spec-create` / `omni-spec-implement`); reserve `disable-model-invocation: true` for workflows that must never auto-fire (e.g. commits, PR posting)
3. Add skill instructions targeting Claude Code
4. Add it to the table above
5. Run `make install`

## Adding a New Agent

1. Start from [`templates/agent-template.md`](templates/agent-template.md): copy it to `agents/{name}.md`, remove the introductory wrapper and outer fenced block so the file begins with YAML frontmatter, then fill in `name`, `description`, and optionally `model`, `readonly`
2. Set `readonly: true` for agents that only read and report (auditors, validators); set `readonly: false` explicitly when the agent writes files or runs state-changing commands
3. Add it to the agents table above
4. Run `make install`

See [AGENTS.md](AGENTS.md) for field reference and conventions.
