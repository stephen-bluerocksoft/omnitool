#!/usr/bin/env bash
# Omnitool - Skill frontmatter and rules size checker
#
# Anthropic's skills guide caps a description at 1,024 characters and forbids
# angle brackets anywhere in frontmatter, because frontmatter is placed in
# the system prompt where markup could inject instructions. This checks every
# skills/*/SKILL.md against both. A description must stay on one line so the
# check can measure it.
#
# It also holds the always-loaded rules -- every rules/*.md, which install.sh
# injects into ~/.claude/CLAUDE.md for every session -- under a size ceiling
# that only moves down: lower it when the rules shrink well below it, and
# raise it only in the PR that grows them, with the reason.
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

RULES_MAX_LINES=8
RULES_MAX_WORDS=100
rules_lines=$(cat rules/*.md | wc -l | tr -d ' ')
rules_words=$(cat rules/*.md | wc -w | tr -d ' ')
if [ "$rules_lines" -gt "$RULES_MAX_LINES" ] || [ "$rules_words" -gt "$RULES_MAX_WORDS" ]; then
    fail "rules/*.md total $rules_lines lines and $rules_words words, over the ceiling of $RULES_MAX_LINES and $RULES_MAX_WORDS -- move the addition into a skill, or raise RULES_MAX_* in scripts/check-skills.sh in this PR and give the reason"
fi

if [ "$failures" -gt 0 ]; then
    echo "$failures check(s) failed."
    exit 1
fi
echo "  ok    every skill description is one line of at most 1,024 characters, with no angle brackets"
echo "  ok    rules/*.md total $rules_lines of $RULES_MAX_LINES lines and $rules_words of $RULES_MAX_WORDS words"
