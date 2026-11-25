#!/usr/bin/env bash
# Omnitool - Tests for skills/omni-pr-create/scripts/check-pr-body.sh
#
# Checks what a drafted pull request body may not hold, what only looks like
# it, the long-lived-branch exception, and that a check that cannot run exits 2.
#
# Usage: make test

set -e
set -o pipefail
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CHECK="$REPO_DIR/skills/omni-pr-create/scripts/check-pr-body.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Git exports these to a rebase's commands and to hooks in a linked worktree,
# where they would aim every git command below at that repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

# The person's own git settings must not decide a test.
export GIT_CONFIG_GLOBAL=/dev/null

failures=0
count=0

record() {
    count=$((count + 1))
    if [ "$1" = "$2" ]; then
        echo "  ok    $3"
    else
        echo "  FAIL  $3"
        echo "        expected: $1"
        echo "        got:      $2"
        failures=$((failures + 1))
    fi
}

git init -q "$work/repo"
cd "$work/repo"
git config user.email test@example.com
git config user.name Test
git commit -q --allow-empty -m one
git branch -M main
git checkout -q -b feature
git commit -q --allow-empty -m two
on_main=$(git rev-parse main)
on_feature=$(git rev-parse feature)

# Exit code for a body given on standard input.
code() {
    local body=$1 rc=0
    shift
    printf '%s\n' "$body" | bash "$CHECK" "$@" >"$work/out" 2>&1 || rc=$?
    echo "$rc"
}

echo "Commit hashes"
for line in "Head is ${on_feature:0:7}." "Built on \`$on_feature\`" "See https://example.com/owner/repo/commit/${on_feature:0:10}" \
    "Rebased onto _${on_main:0:8}_ (base)" "${on_feature:0:9}-dirty" "${on_feature:0:8}" "* ${on_feature:0:7} (HEAD -> feature) two"; do
    record 1 "$(code "$line")" "$line"
done
record yes "$(grep -q '^line 1: a commit hash' "$work/out" && echo yes || echo no)" "the line is named"
for line in "Run \`tool upgrade 1a2b3c4d5e6f\`" "Pins an action to 0123456789abcdef0123456789abcdef01234567" \
    "Image sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" "Request 550e8400-e29b-41d4-a716-446655440000" \
    "The badge turns #1a2b3c4d when it fails" "A defaced or effaced label" "Ticket 1234567 has the history" "${on_main:0:6} is too short"; do
    record 0 "$(code "$line")" "not a commit here: $line"
done

echo "Lists of commits"
for line in "## Commits" "### Commit list" "## Commits (3)" "## Commits in this PR" "Commits:" "**Commits:**" $'## Commits\r' \
    $'- feat: add a thing\n- fix(core): mend it' $'* `feat!: add a thing`\n* docs: say so' $'1. feat: one\n2. fix: two' \
    $'- [x] feat: one\n- [x] fix: two' $'- feat: one\n\n- fix: two' $'- feat: one\n  - detail\n- fix: two'; do
    record 1 "$(code "$line")" "$line"
done
for line in "- fix: one change described in the words of its subject" "Commits the transaction before it replies" \
    "## Commits the transaction first" $'- fix: one\n\n## Test plan\n\n- test: two'; do
    record 0 "$(code "$line")" "not a list: $line"
done

echo "Check and gate numbers"
while IFS= read -r line; do
    record 1 "$(code "$line")" "$line"
done <<'LINES'
139 passed
139 passed (4.1s)
Tests  139 passed (139)
139 passing (2s)
12 tests passed in 4.1s
Ran 139 tests in 4.2s
139 tests, 0 failures
All 139 unit tests pass.
1,204 passed, 3 skipped
make check: 42 checks, 0 failed
All 51 checks pass
make check passes (42/42)
Gate 3 passed
gates: 12/12
Coverage: 96%
coverage is 96%
96% line coverage
0 errors, 0 warnings
LINES
while IFS= read -r line; do
    record 0 "$(code "$line")" "not a result: $line"
done <<'LINES'
## Summary
Retries 3 failed requests before it gives up
Two checks run before the write
- [ ] `make test` passes
- [ ] the gate refuses a blank name
- [ ] Test: 404 renders for an unknown id
If 3 checks fail, the circuit opens
Health checks: 2 per minute
Adds gate 4 to the release workflow
Fails under a coverage of 80%
Raises the 80% coverage floor
The list shows 12 of 40 rows
Tests that a 2026/01/02 date is read
Closes #12
LINES
record 0 "$(code "")" "an empty body"

echo "A hash on a long-lived branch, cited for a reason"
record 1 "$(code "Reverts ${on_main:0:9}, which broke sign-in.")" "fails until it is named"
record 0 "$(code "Reverts ${on_main:0:9}, which broke sign-in." --cite "${on_main:0:9}")" "passes when it is"
record 0 "$(code "Reverts $on_main, which broke sign-in." --cite "${on_main:0:9}")" "whole, when its short form is named"
record 1 "$(code "Reverts ${on_main:0:9} and ${on_feature:0:9}." --cite "${on_main:0:9}")" "which excuses no other"
record 1 "$(code "Head is ${on_feature:0:9}." --cite "${on_feature:0:9}")" "a hash on no long-lived branch cannot be named"
record yes "$(grep -q 'not on a long-lived branch' "$work/out" && echo yes || echo no)" "and it says so"
record 1 "$(code "Reverts 1a2b3c4." --cite 1a2b3c4)" "nor one that is not a commit"
for branch in master dev; do
    git update-ref "refs/remotes/origin/$branch" feature
    record 0 "$(code "Reverts ${on_feature:0:9}." --cite "${on_feature:0:9}")" "a remote's $branch counts"
    git update-ref -d "refs/remotes/origin/$branch"
done

echo "What it cannot check exits 2"
record 2 "$(code "text" --nope)" "an unknown option"
record 2 "$(code "text" --cite)" "a citation with no hash"
record 2 "$(code "text" --cite HEAD)" "a citation that is a name, not a hash"
rc=0
(cd "$work" && printf 'x\n' | bash "$CHECK" >/dev/null 2>&1) || rc=$?
record 2 "$rc" "outside a repository"

echo ""
echo "$count checks, $failures failed"
[ "$failures" -eq 0 ]
