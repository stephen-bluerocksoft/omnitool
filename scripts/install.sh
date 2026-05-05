#!/bin/bash
# Omnitool - Installation Script
# Copies personal skills and agents to Cursor global directory

set -e
set -o pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$REPO_DIR/skills"
AGENTS_DIR="$REPO_DIR/agents"

CURSOR_SKILLS_DIR="$HOME/.cursor/skills"
CURSOR_AGENTS_DIR="$HOME/.cursor/agents"

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

echo "Cleaning up deprecated files..."
cleanup_deprecated "$HOME/.cursor/commands" "${DEPRECATED_COMMANDS[@]}"
cleanup_deprecated "$CURSOR_AGENTS_DIR" "${DEPRECATED_AGENTS[@]}"

echo "Installing skills..."
install_skills "$SKILLS_DIR" "$CURSOR_SKILLS_DIR" "Cursor (~/.cursor/skills)"

echo "Installing agents..."
install_files "$AGENTS_DIR" "$CURSOR_AGENTS_DIR" "Cursor (~/.cursor/agents)"

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
