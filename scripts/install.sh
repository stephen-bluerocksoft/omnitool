#!/bin/bash
# Omnitool - Installation Script
# Copies personal commands to Cursor global directory

set -e
set -o pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
COMMANDS_DIR="$REPO_DIR/commands"

CURSOR_COMMANDS_DIR="$HOME/.cursor/commands"

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

echo "Installing commands..."
install_files "$COMMANDS_DIR" "$CURSOR_COMMANDS_DIR" "Cursor (~/.cursor/commands)"

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
