#!/usr/bin/env bash
# Omnitool - Skill frontmatter checker
#
# Anthropic's skills guide caps a description at 1,024 characters and forbids
# angle brackets anywhere in frontmatter, because frontmatter is placed in
# the system prompt where markup could inject instructions. This checks every
# skills/*/SKILL.md against both. A description must stay on one line so the
# check can measure it.
#
# Usage: make check   (or ./scripts/check-skills.sh)

set -e
set -o pipefail
set -u
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

failures=0

fail() {
    echo "  FAIL  $*"
    failures=$((failures + 1))
}

for skill_file in skills/*/SKILL.md; do
    frontmatter=$(awk '/^---$/ { n++; next } n == 1' "$skill_file")
    description=$(awk '/^description:/ { sub(/^description:[[:space:]]*/, ""); gsub(/"/, ""); print; exit }' <<<"$frontmatter")
    case $description in
        "" | ">"* | "|"*)
            fail "$skill_file has no one-line description; write it on the description: line"
            continue
            ;;
    esac
    [ "${#description}" -le 1024 ] \
        || fail "$skill_file description is ${#description} characters; the limit is 1,024"
    if grep -q '[<>]' <<<"$frontmatter"; then
        fail "$skill_file frontmatter contains < or >, which skill frontmatter does not allow"
    fi
done

if [ "$failures" -gt 0 ]; then
    echo "$failures check(s) failed."
    exit 1
fi
echo "  ok    every skill description is one line of at most 1,024 characters, with no angle brackets"
