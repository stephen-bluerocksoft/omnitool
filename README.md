# Omnitool

Personal AI coding toolkit -- commands, workflows, and tools that augment agentic development in Cursor.

Named after the [omni-tool](https://masseffect.fandom.com/wiki/Omni-tool) from Mass Effect: a universal device that does everything.

## Quick Start

```bash
make install
```

This copies all commands to `~/.cursor/commands/` so they are available globally via `/omni.command-name` in Cursor.

## Commands

| Command | Description |
| ------- | ----------- |
| `/omni.add-feature` | Run the spec-first development workflow for a feature or change |
| `/omni.align-spec` | Audit alignment between spec artifacts and implementation |
| `/omni.commit` | Analyze changes and create logically grouped conventional commits |
| `/omni.compact` | Compact a feature branch's noisy commit history into clean, logical commits |
| `/omni.create-pr` | Create a pull request from the current branch using gh CLI |
| `/omni.review-pr` | Comprehensive PR review with inline GitHub comments |
| `/omni.timetrack` | Generate a timetrack entry summarizing work for management |

## Installation

```bash
# Install commands
make install

# Pull latest and reinstall
make update
```

## Adding a New Command

1. Create `commands/omni.{action}.md` with a `description` in YAML frontmatter
2. Use `$ARGUMENTS` to capture user input
3. Add it to the table above
4. Run `make install`
