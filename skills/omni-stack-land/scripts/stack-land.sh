#!/usr/bin/env bash
# Omnitool - Build a stack of branches in a throwaway clone, ready to push
#
# For each branch, bottom first: applies its changes, merges the branch below
# into it with --no-ff, uses the prepared resolution of each conflict, and
# applies the changes that need the branch below. Then it refuses a stack in
# which any remote head is not an ancestor of its new head, runs the project's
# gates on every head, and prints what a push would send, with the one atomic
# push that sends exactly that. It pushes nothing: the caller runs that command
# once the person has approved the table. It reads the repository and never
# writes to it or its worktrees.
#
# A branch starts from its local head, or from the remote's when there is no
# local branch.
#
# The plan folder:
#   stack                     the branches, bottom first, one per line
#   gates                     an executable, run in the clone with the branch
#                             name as its argument; exit 0 passes the head
#   changes/<branch>/*.patch  applied in name order before the merge, each one
#                             commit, whose message is in the .msg beside it
#   after/<branch>/*.patch    the same, applied after the merge
#   resolve/<branch>/<path>   the whole file to use where <path> conflicts
#                             (a conflict settled by deleting is not supported).
#                             One that still conflicts after the text below it
#                             changed is used as it is: each is listed, to be
#                             read again
#
# Usage:
#   stack-land.sh build --repo DIR --remote NAME --plan DIR --work NEW_DIR
#   stack-land.sh ready --work DIR      check the remote still holds the old heads
#   stack-land.sh verify --work DIR     check the remote holds the new heads
#
# Exit 0 when it is done. Exit 1 when the stack may not land as planned, saying
# why. Exit 2 on a usage or environment error.

set -e
set -o pipefail
set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

fail() {
    echo "stack-land: $1" >&2
    exit 2
}

# A command that dies under set -e exits with its own status; 1 would read as a
# refusal.
finished=0
trap 'case $?:$finished in
    2:* | *:1) ;;
    *) echo "stack-land: the build itself failed" >&2; exit 2 ;;
esac' EXIT

stop() {
    echo "STOP  $1"
    finished=1
    exit 1
}

command=${1-}
[ "$#" -eq 0 ] || shift
repo="" remote="" plan="" work=""
while [ "$#" -gt 0 ]; do
    [ "$#" -ge 2 ] || fail "$1 needs a value"
    case $1 in
        --repo) repo=$2 ;;
        --remote) remote=$2 ;;
        --plan) plan=$2 ;;
        --work) work=$2 ;;
        *) fail "unknown option: $1" ;;
    esac
    shift 2
done
[ -n "$work" ] || fail "--work is required"

# The commit a branch has on the remote, empty when the remote has no such branch.
remote_head() {
    git -C "$work/clone" ls-remote land "refs/heads/$1" | awk '{ print $1 }'
}

if [ "$command" = ready ] || [ "$command" = verify ]; then
    [ -f "$work/payload" ] || fail "no build in $work"
    wrong=0
    while read -r branch new old; do
        want=$new
        [ "$command" = verify ] || want=$old
        now=$(remote_head "$branch") || fail "cannot read the remote"
        if [ "${now:-new}" = "$want" ]; then
            echo "ok    $branch $want"
        else
            echo "WRONG $branch is ${now:-missing} on the remote, not $want"
            wrong=1
        fi
    done <"$work/payload"
    finished=1
    exit "$wrong"
fi

[ "$command" = build ] || fail "usage: stack-land.sh build|ready|verify (see the header)"
[ -n "$repo" ] && [ -n "$remote" ] && [ -n "$plan" ] || fail "build needs --repo, --remote, --plan, and --work"
repo=$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null) || fail "--repo is not a repository"
plan=$(cd "$plan" 2>/dev/null && pwd -P) || fail "no such plan folder"
# Heads are read from where the push goes, which may not be where fetches come from.
url=$(git -C "$repo" remote get-url --push --all "$remote" 2>/dev/null) || fail "no remote '$remote' in $repo"
[ "$(wc -l <<<"$url")" -eq 1 ] || fail "'$remote' has several push URLs, which no one push updates together"
[ ! -e "$work" ] || fail "$work exists; name a new folder"
parent=$(cd "$(dirname "$work")" 2>/dev/null && pwd -P) || fail "no folder to make $work in"
work="$parent/$(basename "$work")"
while IFS= read -r tree; do
    case $work/ in
        "${tree#worktree }"/*) fail "$work is inside a worktree of the repository" ;;
    esac
done < <(git -C "$repo" worktree list --porcelain | grep '^worktree ')

[ -f "$plan/stack" ] || fail "the plan has no stack file"
[ -x "$plan/gates" ] || fail "the plan has no executable gates file"
stack=()
while IFS= read -r branch || [ -n "$branch" ]; do
    [ -n "$branch" ] || continue
    git check-ref-format --branch "$branch" >/dev/null 2>&1 || fail "not a branch name: $branch"
    case $branch in
        main | master | dev) fail "$branch is a long-lived branch; a stack lands on it through review" ;;
    esac
    case " ${stack[*]+"${stack[*]}"} " in
        *" $branch "*) fail "$branch is in the stack twice" ;;
    esac
    stack+=("$branch")
done <"$plan/stack"
[ "${#stack[@]}" -gt 0 ] || fail "the stack is empty"

# Every planned file belongs to a branch of the stack, and every patch has a message.
for kind in changes after resolve; do
    [ -d "$plan/$kind" ] || continue
    while IFS= read -r file; do
        owner=""
        for branch in "${stack[@]}"; do
            case $file in "$plan/$kind/$branch/"*) owner=$branch ;; esac
        done
        [ -n "$owner" ] || fail "${file#"$plan"/} is for no branch of the stack"
        [ "$kind" != resolve ] || continue
        [ "$(dirname "$file")" = "$plan/$kind/$owner" ] || fail "${file#"$plan"/} is not directly in its branch's folder"
        case $file in
            *.patch) [ -s "${file%.patch}.msg" ] || fail "${file#"$plan"/} has no message beside it" ;;
            *.msg) [ -f "${file%.msg}.patch" ] || fail "${file#"$plan"/} has no patch beside it" ;;
            *) fail "${file#"$plan"/} is neither a .patch nor a .msg" ;;
        esac
    done < <(find "$plan/$kind" -type f)
done

mkdir "$work"
clone="$work/clone"
git clone -q --no-hardlinks --no-checkout "$repo" "$clone"
in_clone() {
    git -C "$clone" -c rerere.enabled=false -c advice.detachedHead=false "$@"
}
for key in user.name user.email; do
    value=$(git -C "$repo" config "$key") || continue
    git -C "$clone" config "$key" "$value"
done
git -C "$clone" remote add land "$url"
: >"$work/resolved"
for branch in "${stack[@]}"; do
    old=$(remote_head "$branch") || fail "cannot read the remote '$remote'"
    if [ -n "$old" ]; then
        in_clone fetch -q land "+refs/heads/$branch:refs/old/$branch"
    elif [ "$branch" = "${stack[0]}" ]; then
        fail "$branch, the bottom of the stack, is not on the remote"
    fi
    start=$(in_clone rev-parse --verify --quiet "refs/remotes/origin/$branch") || start=$old
    [ -n "$start" ] || fail "no branch $branch here or on the remote"
    in_clone update-ref "refs/heads/$branch" "$start"
done
# Nothing in the clone can reach the person's repository from here on.
git -C "$clone" remote remove origin

# Applies a branch's patches of one kind, each as a commit.
apply_patches() {
    local patch
    for patch in "$plan/$1/$2"/*.patch; do
        [ -e "$patch" ] || continue
        in_clone apply --index --whitespace=nowarn "$patch" || stop "$1/$2/$(basename "$patch") does not apply to $2"
        in_clone commit -q -F "${patch%.patch}.msg"
    done
}

# Merges the branch below, settling each conflict with its prepared file.
merge_up() {
    local branch=$1 below=$2 resolve="$plan/resolve/$1" path rest="" missing=""
    if ! in_clone merge --no-ff -q -m "chore: merge $below into $branch" "refs/heads/$below" >"$work/merge.log" 2>&1; then
        in_clone diff --name-only --diff-filter=U -z >"$work/conflicts"
        [ -s "$work/conflicts" ] || stop "$below does not merge into $branch: $(tail -n 3 "$work/merge.log")"
        while IFS= read -r -d '' path; do
            if [ -f "$resolve/$path" ]; then
                if grep -qE '^(<<<<<<<|>>>>>>>)( |$)' "$resolve/$path"; then
                    stop "resolve/$branch/$path still holds conflict markers"
                fi
                # Written through, a link would reach a file outside the clone.
                [ ! -L "$clone/$path" ] || rm "$clone/$path"
                cat "$resolve/$path" >"$clone/$path"
                in_clone add -- "$path"
                printf 'resolved  %-18s %s\n' "$branch" "$path" >>"$work/resolved"
            else
                missing="$missing $path"
            fi
        done <"$work/conflicts"
        [ -z "$missing" ] || stop "$below conflicts with $branch, with no prepared resolution:$missing"
        in_clone commit -q --no-edit --cleanup=strip
    else
        : >"$work/conflicts"
    fi
    [ -d "$resolve" ] || return 0
    while IFS= read -r path; do
        path=${path#"$resolve"/}
        tr '\0' '\n' <"$work/conflicts" | grep -qxF -e "$path" || rest="$rest $path"
    done < <(find "$resolve" -type f)
    [ -z "$rest" ] || stop "$branch did not conflict in, so the resolution is out of date:$rest"
}

below=""
for branch in "${stack[@]}"; do
    in_clone checkout -q -f "$branch"
    apply_patches changes "$branch"
    [ -z "$below" ] || merge_up "$branch" "$below"
    apply_patches after "$branch"
    below=$branch
done

refused=""
moved=0
for branch in "${stack[@]}"; do
    new=$(in_clone rev-parse "refs/heads/$branch")
    old=$(in_clone rev-parse --verify --quiet "refs/old/$branch") || old=""
    [ "$new" = "$old" ] || moved=1
    if [ -n "$old" ] && ! in_clone merge-base --is-ancestor "$old" "$new"; then
        refused="$refused
      $branch: the remote's head $old is not an ancestor of $new"
    fi
    printf '%s %s %s\n' "$branch" "$new" "${old:-new}"
done >"$work/heads"
[ -z "$refused" ] || stop "a push without force would be rejected, and forcing it would lose commits:$refused"
[ "$moved" -eq 1 ] || stop "every head is already on the remote: nothing to push"

while read -r branch new old; do
    in_clone checkout -q -f --detach "$new"
    # What one head's gates leave behind must not let the next head pass.
    # clean does not enter a submodule; deinit empties each.
    in_clone submodule --quiet deinit -f --all
    in_clone clean -q -ffdx
    if ! (cd "$clone" && "$plan/gates" "$branch") >"$work/gates.log" 2>&1 </dev/null; then
        tail -n 20 "$work/gates.log"
        stop "the gates fail on $branch"
    fi
done <"$work/heads"

short() {
    in_clone rev-parse --short=10 "$1"
}

refs=""
below=""
printf '%-28s %-10s %-10s %7s %5s %7s %7s\n' branch old new commits files added removed
while read -r branch new old; do
    from=$old
    [ "$old" != new ] || from=$below
    sizes=$(in_clone diff --no-ext-diff --numstat "$from" "$new" | awk '{ f++; a += $1; r += $2 } END { printf "%5d %+7d %7s", f, a, "-" (r + 0) }')
    printf '%-28s %-10s %-10s %7s %s\n' "$branch" "$(if [ "$old" = new ]; then echo new; else short "$old"; fi)" \
        "$(short "$new")" "$(in_clone rev-list --count "$from..$new")" "$sizes"
    in_clone log --first-parent --format='    %h %s' "$from..$new"
    [ "$new" = "$old" ] || refs="$refs $new:refs/heads/$branch"
    below=$new
done <"$work/heads"
mv "$work/heads" "$work/payload"

cat "$work/resolved"

echo ""
# The person's own settings could add tags or submodules to a push.
shown=$url
if [[ $url =~ ^([a-z+]+://)[^/@]*@(.*)$ ]]; then
    shown="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
fi
echo "To $shown, all of it or none of it:"
printf '    git -C %q push --no-follow-tags --recurse-submodules=no --atomic land%s\n' "$clone" "$refs"
finished=1
