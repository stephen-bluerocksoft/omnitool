#!/bin/bash
# Omnitool - Installation Script
# Copies personal skills and agents to Claude Code, and injects the global rules
# into ~/.claude/CLAUDE.md so they load every session.

set -e
set -o pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$REPO_DIR/skills"
AGENTS_DIR="$REPO_DIR/agents"
RULES_DIR="$REPO_DIR/rules"

CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_AGENTS_DIR="$HOME/.claude/agents"
CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

# Omnitool markers for CLAUDE.md rule injection (kept separate from the BRS block)
OMNITOOL_START_MARKER="<!-- OMNITOOL-RULES-START -->"
OMNITOOL_END_MARKER="<!-- OMNITOOL-RULES-END -->"

# Rules injected into CLAUDE.md, in reading order. Add new rule files here.
RULES_ORDER=(
    "global-defaults"
    "commit-proposals"
    "spec-first-development"
    "task-management"
    "documentation-standards"
)

DEPRECATED_COMMANDS=(
    "omni.add-feature.md"    # old deprecated
    "omni.align-spec.md"     # old deprecated
    "omni.commit.md"         # migrated to skills
    "omni.compact.md"        # migrated to skills
    "omni.pr.create.md"      # migrated to skills
    "omni.pr.review.md"      # migrated to skills
    "omni.spec.create.md"    # migrated to skills
    "omni.spec.align.md"     # migrated to skills
    "omni.spec.implement.md" # migrated to skills
    "omni.plan.implement.md" # migrated to skills
    "omni.timetrack.md"      # migrated to skills
)

DEPRECATED_AGENTS=(
    "repo-test-auditor.md"   # consolidated into BRS test-auditor
)

echo "Omnitool Installer"
echo "=================="
echo ""

install_files() {
    local source_dir="$1"
    local target_dir="$2"
    local label="$3"

    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
    fi

    local count=0
    for src_file in "$source_dir"/*.md; do
        if [ -f "$src_file" ]; then
            filename=$(basename "$src_file")
            target="$target_dir/$filename"

            if [ -L "$target" ] || [ -f "$target" ]; then
                rm "$target"
            fi

            cp "$src_file" "$target"
            count=$((count + 1))
        fi
    done

    echo "  Installed $count files to $label"
}

install_skills() {
    local source_dir="$1"
    local target_dir="$2"
    local label="$3"

    mkdir -p "$target_dir"

    local count=0
    for skill_dir in "$source_dir"/*/; do
        if [ -f "$skill_dir/SKILL.md" ]; then
            skill_name=$(basename "$skill_dir")
            target="$target_dir/$skill_name"

            if [ -d "$target" ]; then
                rm -rf "$target"
            fi

            cp -r "$skill_dir" "$target"
            count=$((count + 1))
        fi
    done

    echo "  Installed $count skills to $label"
}

cleanup_deprecated() {
    local target_dir="$1"
    shift
    for old_file in "$@"; do
        target="$target_dir/$old_file"
        if [ -L "$target" ] || [ -f "$target" ]; then
            rm "$target"
            echo "  Removed deprecated: $old_file"
        fi
    done
}

install_claude_md() {
    # Concatenate the ordered rule files into one block, then inject it into
    # ~/.claude/CLAUDE.md between OMNITOOL markers. Idempotent: replaces the block
    # if present, appends it otherwise. Never touches the BRS-CORE-STANDARDS block.
    local rules_content
    rules_content=$(mktemp)
    local found=0
    for rule in "${RULES_ORDER[@]}"; do
        local rule_file="$RULES_DIR/$rule.md"
        if [ -f "$rule_file" ]; then
            cat "$rule_file" >> "$rules_content"
            echo "" >> "$rules_content"
            found=$((found + 1))
        fi
    done

    if [ "$found" -eq 0 ]; then
        echo "  Warning: no rule files found in $RULES_DIR, skipping CLAUDE.md install"
        rm -f "$rules_content"
        return
    fi

    mkdir -p "$(dirname "$CLAUDE_MD")"

    if [ ! -f "$CLAUDE_MD" ]; then
        {
            echo "$OMNITOOL_START_MARKER"
            cat "$rules_content"
            echo "$OMNITOOL_END_MARKER"
        } > "$CLAUDE_MD"
        echo "  Created ~/.claude/CLAUDE.md with omnitool rules"
    elif grep -qF "$OMNITOOL_START_MARKER" "$CLAUDE_MD"; then
        local tmp_file
        tmp_file=$(mktemp)
        awk -v start="$OMNITOOL_START_MARKER" -v end="$OMNITOOL_END_MARKER" -v file="$rules_content" '
            $0 == start { print; system("cat " file); printing=0; next }
            $0 == end { print; printing=1; next }
            printing!=0 { print }
            BEGIN { printing=1 }
        ' "$CLAUDE_MD" > "$tmp_file"
        mv "$tmp_file" "$CLAUDE_MD"
        echo "  Updated omnitool rules in ~/.claude/CLAUDE.md"
    else
        {
            echo ""
            echo "$OMNITOOL_START_MARKER"
            cat "$rules_content"
            echo "$OMNITOOL_END_MARKER"
        } >> "$CLAUDE_MD"
        echo "  Appended omnitool rules to ~/.claude/CLAUDE.md"
    fi

    rm -f "$rules_content"
}

echo "Cleaning up deprecated files..."
cleanup_deprecated "$CLAUDE_COMMANDS_DIR" "${DEPRECATED_COMMANDS[@]}"
cleanup_deprecated "$CLAUDE_AGENTS_DIR" "${DEPRECATED_AGENTS[@]}"

echo "Installing skills..."
install_skills "$SKILLS_DIR" "$CLAUDE_SKILLS_DIR" "Claude (~/.claude/skills)"

echo "Installing agents..."
install_files "$AGENTS_DIR" "$CLAUDE_AGENTS_DIR" "Claude (~/.claude/agents)"

echo "Installing rules..."
install_claude_md

echo ""
echo "Installation complete!"
echo ""
echo "Available skills:"
for skill_dir in "$SKILLS_DIR"/*/; do
    if [ -f "$skill_dir/SKILL.md" ]; then
        echo "  $(basename "$skill_dir")"
    fi
done
echo ""
echo "Available agents:"
for agent_file in "$AGENTS_DIR"/*.md; do
    if [ -f "$agent_file" ]; then
        filename=$(basename "$agent_file" .md)
        echo "  $filename"
    fi
done
echo ""
echo "Rules installed to ~/.claude/CLAUDE.md between OMNITOOL markers."
