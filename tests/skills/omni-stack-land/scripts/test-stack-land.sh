#!/usr/bin/env bash
# Omnitool - Tests for skills/omni-stack-land/scripts/stack-land.sh
#
# Builds a stack of three branches in a temporary repository with a local
# remote, and checks a clean landing from build to verify, conflicts with and
# without a prepared resolution, a rewritten tip, failing gates, and that the
# person's own repository is never touched.
#
# Usage: make test

set -e
set -o pipefail
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
LAND="$REPO_DIR/skills/omni-stack-land/scripts/stack-land.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Git exports these to a rebase's commands and to hooks in a linked worktree,
# where they would aim every git command below at that repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

# The person's own git settings must not decide a test.
export HOME="$work" GIT_CONFIG_GLOBAL="$work/.gitconfig"
git config --global init.defaultBranch main

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

yes_if() {
    if "$@" >/dev/null 2>&1; then echo yes; else echo no; fi
}

commit_file() { # repo file text message
    mkdir -p "$(dirname "$1/$2")"
    printf '%s\n' "$3" >"$1/$2"
    git -C "$1" add -- "$2"
    git -C "$1" commit -q -m "$4"
}

# A remote and a clone of it holding main and the stack s/one, s/two, s/three,
# each branch adding its own file, with two worktree edits of the person's own.
new_stack() {
    here="$work/$1"
    repo="$here/repo"
    plan="$here/plan"
    mkdir -p "$here"
    git init -q --bare "$here/remote.git"
    git init -q "$repo"
    git -C "$repo" config user.name Test
    git -C "$repo" config user.email test@example.com
    commit_file "$repo" shared.txt base "feat: start"
    git -C "$repo" branch -M main
    git -C "$repo" remote add origin "$here/remote.git"
    for b in one two three; do
        git -C "$repo" checkout -q -b "s/$b"
        commit_file "$repo" "$b.txt" "$b" "feat: add $b"
    done
    git -C "$repo" push -q origin main s/one s/two s/three
    git -C "$repo" checkout -q main
    printf 'mine\n' >"$repo/shared.txt"
    printf 'mine\n' >"$repo/untracked.txt"
    mkdir -p "$plan"
    printf 's/one\ns/two\ns/three\n' >"$plan/stack"
    gate 'test -f one.txt'
}

gate() {
    printf '#!/bin/sh\n%s\n' "$1" >"$plan/gates"
    chmod +x "$plan/gates"
}

# change BRANCH FILE TEXT [changes|after] -- plans a patch that replaces a file,
# made against the file as it is on the branch, or as given in $5.
change() {
    local kind=${4:-changes} scratch="$here/scratch" dir="$plan/${4:-changes}/$1"
    rm -rf "$scratch"
    git clone -q "$repo" "$scratch" 2>/dev/null
    git -C "$scratch" checkout -q -f "s/${1#s/}"
    [ -z "${5-}" ] || { printf '%s\n' "$5" >"$scratch/$2"; git -C "$scratch" add "$2"; }
    printf '%s\n' "$3" >"$scratch/$2"
    git -C "$scratch" add -N -- "$2"
    mkdir -p "$dir"
    git -C "$scratch" diff -- "$2" >"$dir/01-$kind.patch"
    printf 'fix: change %s on %s\n' "$2" "$1" >"$dir/01-$kind.msg"
}

state() {
    git -C "$repo" for-each-ref
    git -C "$repo" worktree list
    git -C "$repo" status --porcelain
    git -C "$repo" rev-parse HEAD
    cat "$repo/shared.txt" "$repo/untracked.txt"
}

remote_heads() {
    git -C "$here/remote.git" for-each-ref --format='%(refname) %(objectname)' refs/heads
}

# Exit code of a build; its output is in $here/out, its clone in $here/land.
build() {
    local rc=0
    bash "$LAND" build --repo "$repo" --remote origin --plan "$plan" --work "$here/land" >"$here/out" 2>&1 || rc=$?
    echo "$rc"
}

ready() {
    local rc=0
    bash "$LAND" ready --work "$here/land" >"$here/ready" 2>&1 || rc=$?
    echo "$rc"
}

said() {
    yes_if grep -q -e "$1" "$here/out"
}

echo "A clean landing"
new_stack clean
change s/one shared.txt changed-by-one
change s/two two.txt $'changed-by-two\nand-more'
gate "test -f one.txt && grep -q changed-by-one shared.txt && echo \"\$1\" >>'$here/gated'"
git -C "$repo" tag -a -m private private-tag s/one
before=$(state)
before_remote=$(remote_heads)
record 0 "$(build)" "a build exits 0"
record "$before" "$(state)" "the person's branches, worktrees, index, and files are as they were"
record "$before_remote" "$(remote_heads)" "nothing was pushed"
record "s/one s/two s/three" "$(paste -sd ' ' "$here/gated")" "the gates ran on every head, bottom first"
clone="$here/land/clone"
record yes "$(yes_if git -C "$clone" merge-base --is-ancestor s/one s/two)" "each branch holds the one below"
record yes "$(yes_if git -C "$clone" merge-base --is-ancestor s/two s/three)" "up to the top"
record 2 "$(git -C "$clone" log -1 --format=%P s/two | wc -w | tr -d ' ')" "by a merge commit, not a fast-forward"
old=$(git -C "$repo" rev-parse --short=10 s/two)
new=$(git -C "$clone" rev-parse --short=10 s/two)
record yes "$(yes_if grep -qE "^s/two +$old +$new +3 +2 +\+3 +-2$" "$here/out")" "the table holds old head, new head, commits, files, and lines"
record yes "$(said 'fix: change two.txt on s/two')" "and the subjects of the new commits"
push=$(sed -n 's/^    \(git -C .* push .*\)$/\1/p' "$here/out")
full=$(git -C "$clone" rev-parse s/two)
record yes "$(yes_if grep -q -e "push .* --atomic land .*$full:refs/heads/s/two" <<<"$push")" "the push names each commit and ref"
record no "$(yes_if grep -qE -e '--force|-f |\+[0-9a-f]{40}|HEAD|--all|--mirror' <<<"$push")" "and forces nothing"
record 1 "$(bash "$LAND" verify --work "$here/land" >/dev/null 2>&1; echo $?)" "verify fails before the push"
record 0 "$(ready)" "and ready passes"
git config --global push.followTags true
eval "$push" 2>/dev/null
record 0 "$(bash "$LAND" verify --work "$here/land" >/dev/null 2>&1; echo $?)" "and passes after it"
record "$full" "$(git -C "$here/remote.git" rev-parse s/two)" "the remote holds the approved commit"
record "" "$(git -C "$here/remote.git" tag)" "and nothing else, whatever the person's push settings"
git config --global --unset push.followTags
record 1 "$(ready)" "ready fails once the heads have moved"
record "$before" "$(state)" "the person's repository is still as it was"
rm -rf "$here/land"
# Another time, so the commits built again differ from those on the remote.
record 1 "$(GIT_COMMITTER_DATE="2001-01-01T00:00:00Z" build)" "landing again from the branches left behind is refused"
record yes "$(said 'not an ancestor')" "because they no longer hold what was pushed"

echo "The remote moved after the build"
new_stack moved
change s/one shared.txt changed-by-one
build >/dev/null
git clone -q "$here/remote.git" "$here/other" 2>/dev/null
git -C "$here/other" config user.name Other
git -C "$here/other" config user.email other@example.com
git -C "$here/other" checkout -q s/two
commit_file "$here/other" other.txt other "feat: another session"
git -C "$here/other" push -q origin s/two
before_remote=$(remote_heads)
push=$(sed -n 's/^    \(git -C .* push .*\)$/\1/p' "$here/out")
rc=0
eval "$push" >/dev/null 2>&1 || rc=$?
record yes "$([ "$rc" -ne 0 ] && echo yes || echo no)" "the push is refused"
record "$before_remote" "$(remote_heads)" "for every branch, not just the one that moved"

record 1 "$(ready)" "and ready says so first"
new_stack rewound
change s/one shared.txt changed-by-one
build >/dev/null
record 0 "$(ready)" "before it moves, ready passes"
git -C "$here/remote.git" update-ref refs/heads/s/one main
record 1 "$(ready)" "a head taken back after the build"
git -C "$here/remote.git" update-ref -d refs/heads/s/one
record 1 "$(ready)" "a branch deleted after the build"

echo "A conflict"
new_stack conflict
git -C "$repo" checkout -q -f s/two
commit_file "$repo" shared.txt two-wrote-this "feat: two edits shared"
git -C "$repo" push -q origin s/two
git -C "$repo" checkout -q main
printf 'mine\n' >"$repo/shared.txt"
change s/one shared.txt one-wrote-this
before=$(state)
record 1 "$(build)" "with no prepared resolution stops"
record yes "$(said 'shared.txt')" "naming the file"
record "$before" "$(state)" "and the person's repository is as it was"
rm -rf "$here/land"
mkdir -p "$plan/resolve/s/two"
printf 'one-and-two\n' >"$plan/resolve/s/two/shared.txt"
git -C "$repo" config rerere.enabled true
record 0 "$(build)" "with one goes on"
record yes "$(said '^resolved  *s/two  *shared.txt$')" "and it is listed for the person to see"
record "chore: merge s/one into s/two" "$(git -C "$here/land/clone" log -1 --format=%B s/two | sed '/^$/d')" "under a message of its own"
record one-and-two "$(git -C "$here/land/clone" show s/three:shared.txt)" "and the resolution reaches the top"
rm -rf "$here/land"
printf '<<<<<<< ours\nx\n' >"$plan/resolve/s/two/shared.txt"
record 1 "$(build)" "a resolution that still holds conflict markers stops"
rm -rf "$here/land"
printf 'one-and-two\n' >"$plan/resolve/s/two/shared.txt"
printf 'x\n' >"$plan/resolve/s/two/two.txt"
record 1 "$(build)" "a resolution of a file that did not conflict stops"
record yes "$(said 'two.txt')" "naming it"
rm -rf "$here/land" "$plan/resolve/s/two/two.txt" "$plan/changes"
record 1 "$(build)" "a resolution of a merge that did not conflict stops"

echo "A conflict in a link"
new_stack link
printf 'private\n' >"$here/private"
for b in one two; do
    git -C "$repo" checkout -q -f "s/$b"
    ln -s "$here/private" "$repo/link"
    [ "$b" = two ] || ln -sf nowhere "$repo/link"
    git -C "$repo" add link
    git -C "$repo" commit -q -m "feat: link on $b"
    git -C "$repo" push -q origin "s/$b"
done
git -C "$repo" checkout -q main
mkdir -p "$plan/resolve/s/two"
printf 'resolved\n' >"$plan/resolve/s/two/link"
record 0 "$(build)" "is settled"
record private "$(cat "$here/private")" "and nothing outside the clone is written"
record resolved "$(git -C "$here/land/clone" show s/three:link)" "by the prepared file"

echo "A tag with a branch's name"
new_stack tagged
git -C "$repo" tag s/one main
change s/one shared.txt changed-by-one
record 0 "$(build)" "is built"
record changed-by-one "$(git -C "$here/land/clone" show refs/heads/s/three:shared.txt)" "from the branch, not the tag"

echo "A change that needs the branch below"
new_stack after
change s/one new.txt from-one
change s/two new.txt changed-by-two after from-one
record 0 "$(build)" "is applied after the merge"
record changed-by-two "$(git -C "$here/land/clone" show s/three:new.txt)" "and reaches the top"

echo "A branch with nothing of its own"
new_stack bare
git -C "$repo" branch -f s/three s/two
git -C "$repo" push -q -f origin s/three
change s/two two.txt changed-by-two
record 0 "$(build)" "is built"
record 2 "$(git -C "$here/land/clone" log -1 --format=%P s/three | wc -w | tr -d ' ')" "with a merge commit, though it could fast-forward"

echo "A rewritten tip"
new_stack rewritten
git -C "$repo" checkout -q -f s/two
git -C "$repo" commit -q --amend -m "feat: two again"
git -C "$repo" checkout -q main
printf 'mine\n' >"$repo/shared.txt"
record 1 "$(build)" "is refused"
record yes "$(said 's/two.*not an ancestor')" "naming the branch"
record no "$(said ' --atomic ')" "with no push to copy"

echo "A branch the remote does not have"
new_stack added
git -C "$repo" checkout -q -f -b s/four s/three
commit_file "$repo" four.txt four "feat: add four"
git -C "$repo" checkout -q main
printf 'mine\n' >"$repo/shared.txt"
printf 's/four\n' >>"$plan/stack"
record 0 "$(build)" "is built"
record yes "$(yes_if grep -qE '^s/four +new ' "$here/out")" "and listed as new"
printf 's/four\n' >"$plan/stack"
rm -rf "$here/land"
record 2 "$(build)" "but not at the bottom, where there is nothing to compare it with"

echo "Gates"
new_stack gates
gate 'test ! -f three.txt || { echo "three is broken"; exit 1; }'
change s/one shared.txt changed-by-one
record 1 "$(build)" "a head that fails them stops"
record yes "$(said 's/three')" "naming it"
record yes "$(said 'three is broken')" "with what they printed"
record no "$(said ' --atomic ')" "and no push to copy"
rm -rf "$here/land"
gate 'echo x >one.txt; git add -A; git -c user.name=G -c user.email=g@example.com commit -q -m gate; git branch -f s/one HEAD'
record 0 "$(build)" "gates that commit"
record no "$(said 'gate$')" "add nothing to what is pushed"
record one "$(git -C "$here/land/clone" show "$(awk '$1 == "s/three" { print $2 }' "$here/land/payload"):one.txt")" "and change no head"

new_stack leftovers
echo cache >"$repo/.git/info/exclude"
git -C "$repo" checkout -q -f s/one
commit_file "$repo" .gitignore cache "chore: ignore cache"
git -C "$repo" checkout -q main
gate 'test -f two.txt || { mkdir -p cache; echo ok >cache/ok; }; test -f cache/ok'
record 1 "$(build)" "what one head's gates leave behind never passes the next"
new_stack submodule
git init -q "$here/sub"
git -C "$here/sub" config user.name Test
git -C "$here/sub" config user.email test@example.com
commit_file "$here/sub" sub.txt sub "feat: start"
git config --global protocol.file.allow always
git -C "$repo" checkout -q -f s/one
git -C "$repo" submodule --quiet add "$here/sub" sub
git -C "$repo" commit -q -m "feat: add sub"
git -C "$repo" push -q origin s/one
git -C "$repo" checkout -q -f main
gate 'git submodule --quiet update --init && { test -f two.txt || echo ok >sub/left; } && test -f sub/sub.txt'
record 0 "$(build)" "a gate can use a submodule"
rm -rf "$here/land"
gate 'git submodule --quiet update --init && { test -f two.txt || echo ok >sub/left; } && test -f sub/left'
record 1 "$(build)" "nor what they leave in a submodule"
git config --global --unset protocol.file.allow

echo "A patch that does not apply"
new_stack patch
change s/one shared.txt changed-by-one
sed -i.bak 's/^-base/-not the base/' "$plan/changes/s/one/01-changes.patch"
rm "$plan/changes/s/one/01-changes.patch.bak"
record 1 "$(build)" "stops"
record yes "$(said '01-changes.patch')" "naming it"

echo "Nothing to land"
new_stack nothing
record 1 "$(build)" "a stack whose heads are all on the remote stops"
record yes "$(said 'nothing to push')" "and says so"

echo "A remote with a credential and one with two push URLs"
new_stack credential
change s/one shared.txt changed-by-one
git config --global "url.$here/remote.git.insteadOf" "https://user:placeholder@example.com/x.git"
git -C "$repo" remote set-url origin "https://user:placeholder@example.com/x.git"
record 0 "$(build)" "a credential in the URL builds"
record no "$(said placeholder)" "and is not printed"
git config --global --remove-section "url.$here/remote.git"
rm -rf "$here/land"
git -C "$repo" remote set-url origin "$here/remote.git"
git clone -q --bare "$here/remote.git" "$here/fork.git"
git -C "$here/fork.git" update-ref -d refs/heads/s/three
git -C "$repo" config remote.origin.pushurl "$here/fork.git"
record 0 "$(build)" "a push URL of its own builds"
record yes "$(yes_if grep -qE '^s/three +new ' "$here/out")" "against the heads the push would meet"
rm -rf "$here/land"
git -C "$repo" remote set-url --add --push origin "$here/remote.git"
record 2 "$(build)" "two push URLs exit 2"

echo "What it cannot run exits 2"
new_stack bad
change s/one shared.txt changed-by-one
record 2 "$(bash "$LAND" >/dev/null 2>&1; echo $?)" "no command"
record 2 "$(bash "$LAND" build --repo "$repo" --remote origin --plan "$plan" >/dev/null 2>&1; echo $?)" "a missing option"
record 2 "$(bash "$LAND" build --repo "$repo" --remote nope --plan "$plan" --work "$here/land" >/dev/null 2>&1; echo $?)" "a remote that does not exist"
record 2 "$(bash "$LAND" build --repo "$repo" --remote origin --plan "$plan" --work "$repo/land" >/dev/null 2>&1; echo $?)" "a work folder inside the repository"
record no "$(yes_if test -e "$repo/land")" "which is not made"
mkdir "$here/land"
record 2 "$(build)" "a work folder that exists"
rmdir "$here/land"
record 2 "$(bash "$LAND" verify --work "$here/none" >/dev/null 2>&1; echo $?)" "a verify with no build"
rm "$plan/changes/s/one/01-changes.msg"
record 2 "$(build)" "a patch with no commit message"
printf 'fix: x\n' >"$plan/changes/s/one/01-changes.msg"
mkdir -p "$plan/changes/s/typo"
cp "$plan"/changes/s/one/* "$plan/changes/s/typo/"
record 2 "$(build)" "a change for a branch not in the stack"
rm -r "$plan/changes/s/typo"
for stray in changes/s/one/02.diff changes/s/one/more/01.patch changes/s/one/01-other.msg; do
    mkdir -p "$(dirname "$plan/$stray")"
    echo x >"$plan/$stray"
    record 2 "$(build)" "a planned file it would not use: $stray"
    rm "$plan/$stray"
done
git -C "$repo" config --unset user.email
git -C "$repo" config user.useConfigOnly true
git config --global user.useConfigOnly true
record 2 "$(build)" "no identity to commit with"
rm -rf "$here/land"
git config --global --unset user.useConfigOnly
git -C "$repo" config user.email test@example.com
rm "$plan/gates"
record 2 "$(build)" "no gates"
gate true
for stack in "" "main" "s/one
s/one" "s/none" "bad..name" "s/one
master" dev; do
    printf '%s\n' "$stack" >"$plan/stack"
    record 2 "$(build)" "the stack '$(paste -sd ' ' "$plan/stack")'"
done

echo ""
echo "$count checks, $failures failed"
[ "$failures" -eq 0 ]
