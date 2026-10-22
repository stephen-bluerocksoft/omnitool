# Review Feedback

How Phase 3 builds the **feedback ledger**: what reviewers have already said about the PR, and where each finding stands at `HEAD`. The ledger is not shown on the page. It feeds the architecture verdict: the design findings reviewers already raised are vetted rather than raised again, and the pending must-fix items decide whether an approval waits on the code review. The skill never decides for itself whether a finding was fixed.

## Fetch

Fetch all three sources from the PR, paging each to the end. Never truncate silently -- if a listing could not be read in full, the coverage notes say so.

```bash
# Formal reviews: verdict, body, the commit reviewed, and the reviewer type
gh api --paginate repos/<owner>/<repo>/pulls/<n>/reviews \
  --jq '.[] | {id, user: .user.login, type: .user.type, state, submitted_at, commit_id, html_url, body}'

# PR conversation comments (people and bots)
gh api --paginate repos/<owner>/<repo>/issues/<n>/comments \
  --jq '.[] | {id, user: .user.login, type: .user.type, created_at, html_url, body}'
```

Inline threads come from GraphQL, the only API that carries resolution state. Page with `after` until `hasNextPage` is false:

```bash
gh api graphql -F owner=<owner> -F repo=<repo> -F n=<n> -F after=<cursor or omit> -f query='
query($owner:String!,$repo:String!,$n:Int!,$after:String){
  repository(owner:$owner,name:$repo){pullRequest(number:$n){
    reviewDecision
    reviewThreads(first:100,after:$after){
      pageInfo{hasNextPage endCursor}
      nodes{isResolved isOutdated path line originalLine
        comments(first:50){nodes{author{login} body url createdAt originalCommit{oid}}}}}}}}'
```

## Sources

Classify every review and comment by what it says, not by who posted it.

| Source | How to recognize it | Treatment |
| ------ | ------------------- | --------- |
| BRS review track | Body opens with `## PR Review:` or `## BRS refresh review` (after any leading HTML comment), whoever posted it. The Cursor automation posts as `cursor[bot]` with a `CURSOR_AUTOMATION_ID` comment; `brs-pr-review` run by a person posts under that person's account. Each poster is its own track | One round per review, findings from its Must Fix and Recommended entries. The round's verdict is the body's callout (`REQUEST CHANGES`, `APPROVE`, ...), not the review state: `cursor[bot]` posts every verdict as `COMMENTED` |
| Architecture verdict track | Body carries `<!-- omni-pr-architecture:verdict -->` -- an earlier run of this skill | One round per review; its findings are architecture findings, and a new run is a later round of this track |
| Human review | A review with a body or `CHANGES_REQUESTED`, from a `User` that is not the BRS track | One finding per change the reviewer asks for |
| Inline thread | Each review thread | Matched to the round that opened it, or a finding of its own |
| Human comment | A conversation comment from a `User` that asks for a change or raises a problem | One finding per request; thanks, status chatter, and questions already answered in the thread are not findings |
| Author reply | A thread reply or conversation comment from the PR author that answers findings ("Fixed in `<sha>`", "Review findings addressed", "declined") | Not a finding; it sets status (below) |
| Finding bot | A `Bot` comment or review that reports problems in the code -- security and secret scanners, code-review bots, license or vulnerability scanners | One finding per reported problem class |
| Status-only bot | A `Bot` that only reports state -- CI results, deploy previews, coverage badges, dependency-update notices | Skipped; list the bots skipped in the coverage notes |

When a bot does both, keep its findings and skip its status lines.

## Findings

Each ledger entry carries:

- **Reviewer and round**: the reviewer, the review date, and the commit reviewed (`commit_id`, or a thread's `originalCommit`). Mark whether that commit is `HEAD`, an earlier commit of the PR, or not reachable from `HEAD` (force-pushed away).
- **ID and severity**: the reviewer's own, when they give them (the BRS track's `M1`, `R2` and Blocker/Critical/Major/Minor). Never invent a severity for a finding that has none -- show none.
- **Kind**: architecture or defect. A BRS round files design findings under its `**Architecture**` category; an architecture verdict round's findings are all architecture; a human reviewer's finding is architecture when it is about structure -- boundaries, data model, contracts, trust boundaries, ownership of rules -- rather than one piece of code. Everything else is a defect.
- **Must fix**: whether the reviewer placed it under Must Fix, or a human reviewer asked for it in a `CHANGES_REQUESTED` review.
- **Headline**: the reviewer's own headline, or a one-line plain-language restatement of their point.
- **Cited paths**: the files the finding names.
- **Link**: the review, thread, or comment URL.

For a scanner finding, the entry is the count, the problem type, and the file paths -- never the matched value, snippet, or anything that would reproduce a secret.

## Status

Status comes from the reviewers and GitHub, in this order; the first that applies wins.

1. **Reported fixed**: a later round on the same track says the finding was fixed (the BRS track's refresh lists prior items "confirmed fixed"), or the reviewer says so in the thread. Name the round that said it.
2. **Carried forward**: a later round on the same track repeats the finding as still open. It shows once, under its latest ID, with the round it was first raised in.
3. **Resolved**: the GitHub thread is resolved, with no later round contradicting it.
4. **Author reports fixed**: the author replied that it is fixed, citing a commit, and no reviewer has confirmed it since. Name the commit. Until a reviewer confirms, it still counts as pending.
5. **Author declined**: the author replied that they will not make the change. Give their one-line reason; it still counts as pending until the reviewer accepts.
6. **Open**: everything else, including threads GitHub marks outdated. Outdated means the commented line moved, not that the problem went away; show it as a fact beside the status.

Then add one fact to every finding that is not reported fixed or resolved: whether its cited code changed after the round's commit, by `git -C "$CLONE" diff --quiet <round commit> "$HEAD" -- <cited paths>`. Report "code changed since" or "code unchanged since" -- never "fixed". When the round's commit is not reachable, say the check could not run.

Reconcile threads to rounds before assigning status. A BRS round posts each finding twice, as a summary entry and as an inline thread, so match them by ID or headline and give the thread the entry's status. Show each finding once, not once per copy. A thread that matches no summary entry is a finding of its own.
