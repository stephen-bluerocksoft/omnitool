#!/usr/bin/env bash
# Omnitool - Check a drafted pull request body
#
# Reads the body on standard input and fails one that holds what GitHub already
# shows and the next push makes wrong: commit hashes, lists of commits, and
# numbers from a check or a gate.
#
# A hash is 7 to 40 lowercase hexadecimal characters that name a commit in this repository.
# A commit on a long-lived branch (main, master, or dev, local or of a remote)
# may be cited for a reason the body gives: name it with --cite. Lists and
# numbers are known by the shapes test runners and git print, so one put into a
# sentence of its own may pass.
#
# Usage: check-pr-body.sh [--cite <hash>]... <body
#
# Exit 0 when the body is clean, 1 naming each line that is not, and 2 when the
# check could not run.

set -e
set -o pipefail
set -u

fail() {
    echo "check-pr-body: $1" >&2
    exit 2
}

git rev-parse --git-dir >/dev/null 2>&1 || fail "not inside a git repository"
# Asking about a hash must not make a partial clone fetch it.
export GIT_NO_LAZY_FETCH=1

cited=""
refused=0
while [ "$#" -gt 0 ]; do
    [ "$1" = --cite ] || fail "usage: check-pr-body.sh [--cite <hash>]... <body"
    [ "$#" -ge 2 ] || fail "--cite needs a hash"
    [[ $2 =~ ^[0-9a-f]{7,40}$ ]] || fail "--cite needs a hash, not '$2'"
    commit=$(git rev-parse --verify --quiet "$2^{commit}") || commit=""
    long_lived=""
    if [ -n "$commit" ]; then
        long_lived=$(git for-each-ref --contains "$commit" --format='%(refname)' refs/heads refs/remotes |
            awk '/^refs\/heads\/(main|master|dev)$/ || /^refs\/remotes\/[^\/]+\/(main|master|dev)$/')
    fi
    if [ -n "$long_lived" ]; then
        cited="$cited $commit"
    else
        echo "--cite $2: not on a long-lived branch"
        refused=1
    fi
    shift 2
done

body=$(tr -d '\r')

# "<line number> <word>" for each word that could be a hash, which git then
# names a commit or not.
words=$(awk '{
    rest = $0
    while (match(rest, /[0-9A-Za-z]+/)) {
        word = substr(rest, RSTART, RLENGTH)
        rest = substr(rest, RSTART + RLENGTH)
        if (length(word) >= 7 && length(word) <= 40 && word ~ /^[0-9a-f]+$/) print NR, word
    }
}' <<<"$body")
hashes=$(while read -r number word; do
    [ -n "$number" ] || continue
    commit=$(git rev-parse --verify --quiet "$word^{commit}") || continue
    # Not a case: inside $(...), bash 3.2 ends at the pattern's parenthesis.
    [[ " $cited " == *" $commit "* ]] || echo "line $number: a commit hash: $word"
done <<<"$words")

shapes=$(awk '
    function hit(why) { print "line " NR ": " why ": " $0 }
    {
        text = tolower($0)
        if (text ~ /^#+[ \t]+commits?([ \t]*[:(].*|[ \t]+(list|history|log|(in|on|of)[ \t]+this).*)?[ \t]*$/ || text ~ /^[ \t]*\**commits\**:/) hit("a list of commits")
        # Subjects listed one after another, with blank lines or details between.
        if (text ~ /^#/) listed = 0
        if (text ~ /^([-*+]|[0-9]+[.)])[ \t]+(\[[ x]\][ \t]+)?`?(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([^)]*\))?!?: /) {
            if (listed) hit("a list of commits")
            listed = 1
        } else if (text ~ /^[^ \t]/) listed = 0
        n = "(^|[^0-9a-z.#/])[0-9][0-9,]*"
        end = "([^a-z]|$)"
        if (text ~ (n "[ \t]+(passed|failed|passing|failing|skipped|xfailed|deselected)([^ a-z]|$|[ \t]+\\(|[ \t]+(in|and)[ \t]+[0-9])") ||
            text ~ (n "[ \t]+([a-z-]+[ \t]+)?(tests?|checks?|gates?)[ \t]+(all[ \t]+)?(pass|passed|passes|failed|green|succeeded)" end) ||
            text ~ (n "[ \t]+tests?([ \t]+in[ \t]+[0-9]|,[ \t]+[0-9])") ||
            text ~ (n "[ \t]+(errors?|failures?|warnings?),[ \t]+[0-9]+[ \t]+(errors?|failures?|warnings?)" end) ||
            text ~ (n "[ \t]+of[ \t]+[0-9][0-9,]*[ \t]+(tests?|checks?|gates?)" end) ||
            (text ~ /(^|[^a-z])(tests?|checks?|gates?|pass(ed|es)?)([^a-z]|$)/ && text ~ /(^|[^0-9a-z.\/])[0-9]+\/[0-9]+([^0-9a-z\/]|$)/) ||
            text ~ /(^|[^a-z])gate[ \t]+[0-9]+[ \t]+(pass|passed|passes|failed|green)([^a-z]|$)/ ||
            text ~ /(^|[^a-z])coverage([ \t]*:[ \t]*|[ \t]+((is|at)[ \t]+)?)[0-9]+(\.[0-9]+)?%/ ||
            (text ~ /[0-9]%[ \t]+([a-z]+[ \t]+)?coverage/ && text !~ /coverage[ \t]+(floor|gate|limit|minimum|target|threshold)/)) hit("a check or gate number")
    }' <<<"$body")

if [ -n "$hashes$shapes" ]; then
    printf '%s\n' "$hashes" "$shapes" | sed '/^$/d'
    exit 1
fi
exit "$refused"
