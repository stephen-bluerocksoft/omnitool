#!/bin/bash
# Omnitool - Installation Script
# Copies personal commands to Cursor global directory

set -e
set -o pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
COMMANDS_DIR="$REPO_DIR/commands"
AGENTS_DIR="$REPO_DIR/agents"

CURSOR_COMMANDS_DIR="$HOME/.cursor/commands"
CURSOR_AGENTS_DIR="$HOME/.cursor/agents"

DEPRECATED_COMMANDS=(
    "omni.add-feature.md"  # replaced by omni.spec.create.md
    "omni.align-spec.md"   # replaced by omni.spec.align.md
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
cleanup_deprecated "$CURSOR_COMMANDS_DIR" "${DEPRECATED_COMMANDS[@]}"

echo "Installing commands..."
install_files "$COMMANDS_DIR" "$CURSOR_COMMANDS_DIR" "Cursor (~/.cursor/commands)"

echo "Installing agents..."
install_files "$AGENTS_DIR" "$CURSOR_AGENTS_DIR" "Cursor (~/.cursor/agents)"

echo ""
echo "Installation complete!"
echo ""
echo "Available commands (use with /omni.<command-name>):"
for cmd_file in "$COMMANDS_DIR"/*.md; do
    if [ -f "$cmd_file" ]; then
        filename=$(basename "$cmd_file" .md)
        echo "  /$filename"
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
