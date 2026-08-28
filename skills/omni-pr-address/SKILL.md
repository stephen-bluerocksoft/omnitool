---
name: omni-pr-address
description: Address review feedback on an open GitHub pull request -- gather every finding, evaluate each on its merits, implement the accepted ones, then reply inline, resolve what changed, and post a summary comment. Never commits or pushes: you decide how the work lands. Use when a pull request you own has review comments to answer. To review someone else's pull request instead, use brs-pr-review.
disable-model-invocation: true
compatibility: Requires gh CLI authenticated with `repo` scope against the PR's repository
---

# omni-pr-address

## Execution Constraint

**The verdict words in this skill are load-bearing.** `ACCEPT`, `REJECT`, `DEFER`, `DECLINE`, and `DISCARD` decide whether code is edited, which reply text is posted, and whether a review thread is resolved. Do NOT paraphrase them, invent alternatives, or blend two together. The same applies to the `gh` invocations below -- a substituted flag silently changes what reaches the pull request.

## Overview

Take review feedback on a pull request you own, judge each finding on its merits, implement the ones that hold up, and report the outcome back to the reviewer where they raised it.

**The evaluation is the point.** Feedback arrives from human reviewers, review bots, and security scanners, all asserting their findings with equal confidence. Some are correct and worth fixing. Some are correct but out of scope. Some are wrong about what the code does. Some are not findings at all -- advisory notes, questions, or vendor boilerplate. Implementing all of it is as wrong as implementing none of it.

Two failure modes sit on either side of this workflow, and most rules below exist to prevent one of them:

- **Blind implementation** -- turning a reviewer's advisory paragraph into a code change nobody asked for.
- **Fluent rationalization** -- talking yourself out of a correct finding, because a persuasive explanation is easier to produce than the command that would have checked it.

**This skill never commits, stages, or pushes.** It edits the working tree and stops. How the work lands -- grouping, commit message, whether to squash -- is the user's call. The skill then reads the sha back out of git and cites it in the replies, so every "Fixed in `<sha>`" points at a commit that is provably on the remote.

## Scope Boundary

| Target | Skill |
| ------ | ----- |
| Review feedback on a pull request you own | `omni-pr-address` (this skill) |
| Reviewing someone else's pull request | `brs-pr-review` -- posts inline comments and a verdict |
| A local branch, commit, or working tree with no PR | `brs-review` -- text output only, never posts |
| Opening the pull request in the first place | `omni-pr-create` |
| An accepted finding that contradicts the spec | `/omni-spec-modify`, then `/omni-spec-implement` |
| Committing and pushing the resulting changes | `/omni-commit` -- the user runs it at the Phase 7 hand-off |

**If the pull request has no feedback, this skill stops.** It exists to answer findings somebody else raised. Do not fall back to reviewing the PR yourself and generating findings to address -- that is `brs-pr-review`'s job, and doing it here manufactures work the reviewer never asked for.

## Verdicts

Exactly five classifications. Four are verdicts assigned in Phase 3; `DISCARD` is assigned in Phase 2 and never reaches evaluation.

| Verdict | Means | Edits code | Replies | Resolves thread |
| ------- | ----- | ---------- | ------- | --------------- |
| `ACCEPT` | The claim holds and the fix belongs in this PR | Yes | Yes | Yes |
| `REJECT` | The claim's premise does not hold against the code at HEAD | No | Yes | No |
| `DEFER` | The claim holds, but the fix belongs elsewhere | No | Yes | No |
| `DECLINE` | The claim holds and we are deliberately not making the change | No | Yes | No |
| `DISCARD` | Not a defect claim at all | No | Only if thread-anchored | No |

`REJECT` covers every flavour of "the premise is wrong": the code does not say what the finding says it says, another mechanism already prevents the failure, or the described path cannot be reached. The evidence differs; the verdict and the reply shape do not.

`DECLINE` exists so a disagreement of judgment is never mislabelled. Folding it into `REJECT` tells a reviewer they erred when they did not. Folding it into `DEFER` promises later work that will not happen. Both put a falsehood on a public thread.

`DEFER` MUST name where the work goes -- an issue number, a named follow-up, or a spec ID. A `DEFER` with no destination is a `DECLINE` in nicer words; downgrade it or take it to the gate.

**Three supporting states, which are not verdicts:**

- `BLOCKED` -- an `ACCEPT` that could not be implemented. It stays `ACCEPT`; it is simply not done.
- `STALE` -- the cited code changed since the feedback was written. Forces a re-read at HEAD before any verdict.
- `OVERRIDE` -- the verdict was set by the user at the triage gate. Recorded in terminal output only, never in public text: a reply states the disposition, never who chose it.

**Do not invent a severity scale.** Carry the source's own label verbatim (`cursor[bot] High`, `brs-pr-review Major`, `GitGuardian`) and use it for exactly one thing: implementation order within `ACCEPT`. Two fixed vocabularies in one file is where substitution errors start. Where the label is *displayed* is Phase 4's call -- a `Raised as` column when sources differ, a hoisted line when they do not.

## Evidence

BRS Core Standards: *claims about what the code does are executed, not reasoned.* A `REJECT` is a claim about what the code does. So is an `ACCEPT`. Every verdict cites evidence by kind:

| Kind | How obtained | Establishes |
| ---- | ------------ | ----------- |
| `read` | Read the cited file at PR HEAD | What the code at that location actually says |
| `grep` | `rg` across the repository | Absence of a symbol; the complete set of call sites |
| `run` | Executed a command, output captured | Behavior, test results, tool availability |
| `diff` | `git diff <base>...HEAD -- <path>` | Whether this PR introduced the condition |
| `history` | `git log`, `gh pr view`, `gh issue view` | That it is handled elsewhere, or already landed |
| `spec` | A cited requirement in `specs/` or the constitution | In scope versus out of scope |

**Minimum evidence per verdict:**

| Verdict | Minimum |
| ------- | ------- |
| `ACCEPT` | `read` of the exact cited location at HEAD, confirming the code says what the finding says it says. For a behavior defect, also the reproduction that becomes Phase 6's failing test. |
| `REJECT` | `read` of the cited lines, **plus** one of `run` / `grep` / `diff` / `history` exhibiting the mechanism that defeats the claim. |
| `DEFER` | `spec` -- the requirement, constitution clause, or PR-body scope statement that excludes it -- **and** a named destination. |
| `DECLINE` | The deliberate choice, cited where it lives (a code comment, an ADR, a prior decision). |
| `DISCARD` | The quoted source sentence establishing that the text is advisory. |

**A `REJECT` supported only by reasoning is forbidden.** If you cannot produce the command or the read, the finding does not become `REJECT`. Take it to the triage gate as an open question, or accept it. This is the skill's central failure mode: "evaluate on the merits" reads as licence to rationalize, and a fluent argument will out-talk a correct bot finding every time. Name the evidence, or do not claim the verdict.

**Secret-scanner findings have their own rule.** Read the flagged line at the flagged commit (`git show <sha>:<path>`) before any verdict:

- Never `REJECT` one without reading the line. Scanners produce real false positives -- a `resolver:` line matching a password heuristic -- but only the read establishes it.
- Never "fix" one by deleting the line. If the secret is real, the value persists in git history and stays valid, so the work is rotation plus history purge, which is not a code edit. Escalate it at the triage gate; this skill does not implement it.

## Instructions

Execute as **eight sequential phases**. Do NOT skip any phase. Three of them stop:

- **Phase 4** is an approval gate -- the verdicts must be reviewed before any code is edited.
- **Phase 7** is a hand-off -- the skill has no commit of its own to make, and waits for the user to land the work.
- **Phase 8** is an approval gate -- nothing is posted to GitHub without an explicit go-ahead.

### Phase 1: Resolve and Collect

Gather every feedback surface verbatim. Do NOT judge, dedupe, or interpret anything in this phase -- it produces a raw corpus and a set of facts about the PR.

1. **Resolve the target** from user input: full URL, `owner/repo#42`, bare `42`, or no input (detect from the current branch with `gh pr view --json number -q .number`). Extract `owner`, `repo`, and the number. If nothing resolves to a PR, stop and say so.

2. **Fetch PR metadata**:

   ```bash
   gh pr view <n> --json number,title,state,isDraft,url,headRefOid,headRefName,baseRefName,headRepositoryOwner,headRepository,maintainerCanModify,reviews,comments
   ```

   - **State**: `MERGED` or `CLOSED` -- stop. There is nothing to push to. Draft PRs proceed normally.
   - **Fork detection**: compare `headRepositoryOwner.login` against `<owner>`. If they differ, this is a fork PR; record whether `maintainerCanModify` is true. Carry this to Phase 8.
   - Store `headRefOid` as `HEAD_SHA` and the `reviews[].commit.oid` values for the staleness check.

3. **Fetch inline review comments**:

   ```bash
   gh api repos/<owner>/<repo>/pulls/<n>/comments --paginate
   ```

4. **Fetch review threads with their resolution state and node IDs**:

   ```bash
   gh api graphql -f query='
     query {
       repository(owner: "<owner>", name: "<repo>") {
         pullRequest(number: <n>) {
           reviewThreads(first: 100) {
             pageInfo { hasNextPage endCursor }
             nodes {
               id
               isResolved
               isOutdated
               path
               line
               comments(first: 20) {
                 nodes { databaseId author { login } body }
               }
             }
           }
         }
       }
     }'
   ```

   `id` is the `PRRT_...` node ID needed to resolve the thread. `comments.nodes[0].databaseId` is the thread root, and is the reply target. If `hasNextPage` is true, paginate with `after: "<endCursor>"`. Never silently truncate -- if you cannot paginate, state the cap and stop.

5. **Identify yourself**: `gh api user --jq .login`, stored as `ME`. Needed for the idempotency scan.

6. **Idempotency scan.** This skill may have run on this PR before, and it MUST NOT ingest its own output as feedback:

   - Exclude every issue comment authored by `ME` whose body begins with `### Review findings addressed` or `### Review findings evaluated`. Record the shas they cite as already-reported work.
   - Exclude every inline comment authored by `ME` that matches a reply template from Phase 8.
   - Threads with `isResolved: true` are already settled. Skip them; do not re-evaluate.
   - A thread whose last comment is a prior reply from `ME` is already addressed, **unless** newer comments followed it -- in which case only the newer comments are candidates.

7. **Prepare the working tree**:

   - `git status --porcelain` -- if the tree is dirty, stop and tell the user to stash, commit, or discard. Do not check out over uncommitted work.
   - Record `STARTING_BRANCH=$(git branch --show-current)`.
   - `gh pr checkout <n>`. If it fails, stop and report the error -- do not assume the working tree matches the PR. If you are already on the PR branch, this is a no-op and `STARTING_BRANCH` equals the PR branch, so Phase 8 has nothing to return to.

8. **If the corpus is empty** -- no unresolved threads, no review bodies, no issue comments with findings -- **stop**. Report the four surfaces checked with counts, and point at `brs-pr-review` if the user wanted a review rather than a response. Do not proceed to Phase 2.

### Phase 2: Extract and Deduplicate

Turn prose into a numbered candidate list. Keep this separate from evaluation: when the same finding appears in both a review body and an inline thread, evaluating as you extract can reach two different verdicts for one defect.

1. **Extract.** Walk every review body, issue comment, and inline comment. Each discrete defect claim becomes a candidate recording: source, source severity label, the claim, cited locations, thread node ID, and reply-target `databaseId`. Findings hide in numbered lists, bolded lead-ins, and `**[area]** X -- Y` bullets -- a single issue comment routinely carries five findings under one `### Recommended` heading.

2. **Classify advisory content as `DISCARD` before evaluation.** Anything that is not a defect claim never enters Phase 3. Record the quoted sentence that establishes it. Recurring carriers:

   - A section that disclaims its own actionability (`Residual (out of scope -- do not treat as a miss)`).
   - A section addressed to the reader as instructions rather than findings (`### Please do not ...`).
   - The reviewer's self-report of what they did not check (`I did not clone ...`, `pytest was not executed in this environment`).
   - Vendor remediation boilerplate -- a scanner's generic "Guidelines to remediate" block is documentation, not a finding. The scanner's actual hit **is** a finding.
   - Praise, summary, and restatements of the PR's own description.

   A question is also a `DISCARD` -- but if it is anchored to a thread it still gets a reply in Phase 8, and that reply answers it.

3. **Deduplicate.** Two candidates merge when they name the same defect, whether or not they cite the same location. On merge: union the cited locations, keep the **highest** source severity, keep the **inline thread's** `databaseId` as the reply target (that is where the reviewer will look), and record both sources. A review body listing five findings alongside five inline threads carrying the same five is ten candidates and five findings.

Do NOT read implementation files, assign verdicts, or drop a candidate for sounding minor. Dropping on judgment is Phase 3's job and needs evidence; dropping here needs only that the source text is not a defect claim.

### Phase 3: Evaluate

Assign every candidate a verdict, backed by evidence at or above the minimum in the Evidence table. Do NOT edit a single file in this phase.

1. **Staleness check first, on every finding.** Compare the thread's `isOutdated` and the review's `commit.oid` against `HEAD_SHA`. If they differ, run `git diff <review-sha>..HEAD -- <path>` before reading anything else. Feedback written against code that has since changed is `STALE` and MUST be re-read at HEAD before a verdict. Skipping this produces a "fix" for a bug that was fixed two commits ago, and a reply announcing it.

2. **Read the code before re-reading the finding.** The source's severity and tone are inputs, not evidence -- a review bot asserts everything with identical confidence. Form your own read of the cited location first.

3. **Gather evidence and assign the verdict.** Record, per finding: verdict, the evidence kinds used, and the specific command or file that produced them. A verdict whose evidence you cannot name is not ready for the gate.

4. **Cross-check every `ACCEPT` against the spec.** In a repo with `specs/`, an accepted finding that contradicts `spec.md` does not get patched into the code -- route it to `/omni-spec-modify` and note that at the gate.

### Phase 4: Triage Gate -- STOP

**This is a decision-review gate, not an edit-permission gate.** Invoking `/omni-pr-address` already authorizes the file edits. What needs review is the judgment: the skill is about to tell a reviewer publicly that they were wrong, or that something is out of scope. Those are the user's calls, and this table is the only place they are reviewable before they become public.

Print **two rendered markdown tables** -- verdicts, then evidence keyed by the same `#`. Do NOT wrap either in a fenced block and do NOT hand-pad columns: the terminal renders GFM, so a fence turns the table into preformatted text and forces manual alignment that breaks on the first long path.

Hoist the source into a line above the table when every finding came from one reviewer. `Raised as` earns a column only when sources genuinely differ (a bot, a scanner, and a human on one PR).

> Raised by **cursor[bot]** -- F1 as High, F3 as Medium.

| # | Verdict | Finding | Location |
| --- | --- | --- | --- |
| F1 | `ACCEPT` | `yq` not installed in the CI job | `test_x.py:211` |
| F2 | `REJECT` | Hardcoded generic password | `Profile.tsx:81` |
| F3 | `DEFER` | Stripe webhook secret not a chart key | `values.production.yaml:54` |

Evidence belongs in the second table, never inline in the first -- multi-line prose inside an aligned grid is what makes a gate unreadable. Bold the load-bearing conclusion so the verdict's basis survives skimming.

| # | Kind | What it showed |
| --- | --- | --- |
| F1 | `read` + `run` | `.github/workflows/test.yml` has no `yq` install step; `yq --version` -- not found. **Claim holds.** |
| F2 | `read` | At the flagged sha the line is `resolver: zodResolver(schema)`. **False positive.** |
| F3 | `spec` | Spec 036 `REQ-001..005` do not cover Stripe. Tracked in #162. |

Code-style every path, symbol, and verdict. That styling is the whole readability gain over a fenced block -- it is what makes `client.py:61` and `_apply_auth` land as identifiers rather than prose.

Then print the counts -- `N findings -- A accept, R reject, D defer, X decline` -- and ask for a go-ahead.

**`DISCARD` is not counted.** It is assigned in Phase 2 and never reaches evaluation, so listing it in a tally that sums to `N` inflates the work and reports boilerplate-skipping as judgment. Its granularity is arbitrary anyway -- a bot's four summary sections are either one discard or four, and nothing decides which. Print the discards below the tables as unnumbered prose, because that list is the anti-cherry-picking check and that is what makes it worth printing at all:

> Not treated as findings: the bot's summary and compliance blocks (praise and restatement), and its two self-disclaimed "Observations (non-blocking)".

A thread-anchored question is the exception. It is a `DISCARD` that still produces public text in Phase 8, so it goes in the verdict table marked `QUESTION` -- never buried in that footnote.

**Override grammar**: `F3 -> accept`, `F5 -> reject`, `F2 -> defer #178`. The user's call sits at the top of the BRS precedence order -- apply it verbatim and mark the finding `OVERRIDE`. A finding flipped away from `ACCEPT` drops out of Phase 5.

Do NOT begin implementing "the obvious ones" while waiting. A reply of "yes, but what about F4?" is **not** a go-ahead: answer the question, then ask again.

### Phase 5: Implement

Implement `ACCEPT` findings only, in source-severity order, one finding at a time. Track which files each finding touched -- Phase 8 needs them twice: to resolve each finding's sha from git, and because the summary bullets are per finding, not per file.

- A finding whose fix contradicts the spec goes through `/omni-spec-modify`, not a direct patch. Never edit code away from the spec.
- A finding whose real fix is credential rotation or history rewriting is not a code edit. It was escalated at the gate; leave it.
- One attempt per finding, with no remediation loop. A finding that cannot be completed becomes `BLOCKED` and surfaces at the Phase 7 hand-off.

**Fix nothing that is not an accepted finding.** Improvements noticed along the way are unrequested code; report them as observations in the terminal output, and keep them out of the diff.

The one that gets through is the small, obviously-correct cleanup in a file you already have open -- an emoji the project's `AGENTS.md` forbids, a lint nit, a name inconsistent with its neighbour. Being right is not the test. It was not raised, not evaluated, and not approved at the gate, so it does not enter the diff. A standards violation is a finding like any other; noticing it yourself moves it past nothing. Take it to the gate as a new finding, or leave it and report it as an observation.

### Phase 6: Verify

**Scope check first.** Every path in the diff MUST trace to an accepted finding:

```bash
git diff --name-only
```

A path no accepted finding touched is unrequested code that reached the working tree. Back it out before running anything else -- `git checkout -- <path>` when the whole file is yours, a reversed hunk when it is not. Do NOT carry it forward to disclose later: a disclosed unrequested change is still an unrequested change, and the user approved a verdict table, not a diff.

Then two layers, both recorded.

1. **Per-finding proof.** For each implemented finding, name the specific check that establishes the fix. For a behavior defect, that check is a test **confirmed to fail against the pre-fix code** -- run it against the unfixed state before you call it passing. For a docs or config defect, it is the render, parse, or lint that would have caught the error.

2. **Suite layer.** Run the layers the diff actually touches:

   | Layer | Detection | Command |
   | ----- | --------- | ------- |
   | Backend (pytest) | `pytest.ini`, `pyproject.toml [tool.pytest]`, `tests/` with `.py` | `cd backend && pytest` (activate the venv first) |
   | Frontend (Jest/Vitest) | `package.json` with a `test` script | `cd frontend && npm test -- --watchAll=false` |
   | E2E (Playwright) | `playwright.config.*` or `e2e/` with `.spec.ts` | `npx playwright test` |

Record two lists, equally load-bearing: **what ran, with results**, and **what did not run, and who covers it**. The second is not optional -- it feeds the summary comment's Verification paragraph verbatim, and BRS Core Standards make reporting it a MUST. Never call a failure pre-existing without running it on the base ref.

### Phase 7: Hand-Off -- STOP

**This skill does not commit, stage, or push.** How the work lands is the user's decision: how to group it, what the message says, whether to squash. Making that call for them would also silently decide what each reply's sha points at.

Report and stop:

- Each accepted finding, what changed for it, and the files it touched.
- Any `BLOCKED` findings, with what blocks them.
- Phase 6's verification results, including what was not run.
- The full list of files left modified in the working tree (`git status --porcelain`).

Then hand off:

> Changes are in the working tree on `<branch>`, uncommitted. Commit and push however you want them to land -- `/omni-commit` groups them into conventional commits. Tell me when the push is done and I will post the replies and the summary.

`/omni-commit` is `disable-model-invocation: true`, so only the user can invoke it. Do not attempt it, and do not hand-roll a commit in its place.

Do NOT post anything to GitHub in this phase. Do NOT switch or clean branches -- the edits are uncommitted on the PR branch, and moving would carry them somewhere they do not belong.

### Phase 8: Verify the Push, then Publish

**Do not treat the user's "pushed" as proof.** It is a claim about the state of the repository, and this skill posts public text that depends on it.

1. **Confirm the work is committed and on the remote:**

   Ask the remote rather than a local tracking ref -- `@{u}` errors out entirely when the branch was pushed without `-u`, and an error is not the same as a mismatch:

   ```bash
   git status --porcelain                 # must be empty
   git fetch origin <headRefName>
   git rev-parse HEAD                     # local head
   git rev-parse FETCH_HEAD               # what the remote actually has -- must match
   ```

   **Stop** if the tree is dirty, if the shas differ, or if the fetch fails. Name what is outstanding and ask again. Never post about work that is not on the remote.

2. **Resolve each accepted finding's sha** from the commits that actually touched its files:

   ```bash
   git log <base>..HEAD --format=%h -1 -- <path> <path>
   ```

   One commit for the batch gives every finding the same sha; separate commits give each finding its own. **If a finding's files produce no commit, that finding did not land** -- reclassify it `BLOCKED` and never say "Fixed" for it.

3. **Confirm the outward bundle.** Enumerate explicitly: the number of inline replies, **the threads to be resolved, by path and line**, and the summary comment. Nothing is posted until the user says go.

   **Fork PRs**: if the head repository is a fork the user cannot push to, they will have discovered it in Phase 7. Post replies and a summary describing the patch, and resolve nothing -- there is no landed commit to back a resolution.

4. **Post inline replies.**

   ```bash
   gh api repos/<owner>/<repo>/pulls/<n>/comments/<databaseId>/replies -f body='<reply text>'
   ```

   Reply to **every** thread you evaluated, whatever the verdict. Fixed templates:

   ```text
   ACCEPT    Fixed in `<sha>`. <One sentence: what changed.>
             `<path>` -- <the specific change>

   REJECT    Not changing this. <One sentence: the premise that does not hold.>
             Evidence: <command run or symbol read> -- <what it showed>.

   DEFER     Out of scope for this PR. <One sentence: what bounds this PR.>
             Tracked: <issue link | follow-up | spec NNN>.

   DECLINE   Deliberate. <One sentence: the choice and why.>

   BLOCKED   Attempted, not landed. <What blocks it.>
   ```

5. **Resolve threads.** The invariant: **every thread this skill resolves is backed by a commit confirmed on the remote in step 1.**

   ```bash
   gh api graphql -f query='mutation {
     resolveReviewThread(input: {threadId: "<PRRT_...>"}) { thread { isResolved } }
   }'
   ```

   Never resolve a `REJECT`, `DEFER`, `DECLINE`, `DISCARD`, or `BLOCKED`, and never resolve a thread you did not reply to first. A finding that HEAD already satisfied gets a reply citing the sha that fixed it and an **open** thread -- the reviewer closes that one, not you. Threads left open are exactly the list of things you pushed back on, which is what makes a closed PR readable later.

6. **Post the summary comment.** Read the body from stdin -- never `--body "$(cat <<'HEREDOC' ...)"`, because bash 3.2 on macOS mis-parses a heredoc inside command substitution and breaks on any unpaired quote. Pick a delimiter the body cannot contain:

   ```bash
   gh pr comment <n> --body-file - <<'PRBODY'
   <summary body>
   PRBODY
   ```

7. **Leave the branch alone.** Return to `STARTING_BRANCH` only if it differs from the PR branch and the tree is clean. **Do NOT delete the PR branch** -- `brs-pr-review` deletes the branch it checked out for a review, but this branch carries the user's commits and the open pull request.

## Output Format

**Tone**: Direct and terse. State what's wrong, where, and what to do. No preamble, no filler, no praise. This governs the summary comment and the inline replies as much as the terminal output.

**The terminal renders GitHub-flavored markdown.** Tables, code spans, and bold all work there. Reach for a fenced block only when the content is genuinely preformatted -- a command, a diff, a template body destined for GitHub. Structured output that a table would carry MUST be a table: a fence around it produces hand-aligned columns that break on the first long path, and it strips the code styling that makes identifiers scannable.

### Summary comment

```text
### Review findings addressed -- `<head-sha>`

<Lede, one sentence with counts: N findings evaluated; A addressed in `<sha>`,
R rejected, D deferred, X declined.>

- **[<area>] <finding headline>** -- <what changed, concretely>. `<path>`, `<path>`
- **[<area>] <finding headline>** -- Rejected: <the premise that does not hold>. Evidence: <what showed it>.
- **[<area>] <finding headline>** -- Deferred to <issue | follow-up | spec NNN>: <why it is not this PR's work>.
- **[<area>] <finding headline>** -- Declined: <the deliberate choice, and why>.

**Verification:** <what was actually run, with results>. <What was NOT run, and who covers it.>

<sub>Not treated as findings: <one clause per DISCARD, with why>.</sub>
```

- **Every finding that was not accepted gets its own bullet, naming the verdict verbatim and the reason.** `Rejected`, `Deferred`, `Declined`, `Blocked` -- the same word the gate assigned. A summary listing only the wins reads like verification and does not get reviewed.
- A bare "Not changed" is not a disposition. It reads as either `REJECT` or `DECLINE`, and the difference is whether the reviewer erred -- the one thing they will look for. Name the verdict.
- A `Rejected` bullet carries the evidence, not just the conclusion; a `Deferred` bullet carries the destination the verdict named. Neither reason may be new -- both restate what was on the Phase 4 table.
- **No "also cleaned up" bullet.** Every bullet maps to a finding the gate approved. A change with no finding behind it should not have survived Phase 6's scope check, and disclosing it here launders it into the record instead of removing it.
- The trailing not-run sentence in **Verification** is mandatory.
- When zero findings were accepted there is no commit: title the comment `### Review findings evaluated -- no code changes`.
- If the run produced more than one commit, the title carries HEAD and each bullet carries its own sha.

### Terminal output

Unfenced, so it renders. Paths, shas, and branches are code-styled:

- **PR** -- `<owner/repo>#<number>`: `<title>`
- **Findings** -- `<N>`: `<A>` accepted, `<R>` rejected, `<D>` deferred, `<X>` declined
- **Landed** -- `<sha>` on `<branch>` (confirmed on remote)
- **Posted** -- `<N>` inline replies, `<M>` threads resolved, 1 summary comment
- **Not run** -- `<what was not verified, and who covers it>`
- **Link** -- `<PR URL>`

The `DISCARD` rule from Phase 4 holds here: no count, and the tally lists verdicts only.

Follow it with the one-line disposition for every finding not accepted -- verdict word plus reason, the same pair the summary comment carries -- then any `BLOCKED` findings, any `OVERRIDE` the user made, and any observation noticed but deliberately left out of the diff. Omit empty sections.

## Important Rules

- **NEVER** implement a finding the user has not approved at the triage gate.
- **NEVER** commit, stage, push, amend, or switch branches away from uncommitted work -- the user decides how the changes land.
- **NEVER** post a `Fixed in <sha>` reply before confirming that sha is on the remote.
- **NEVER** resolve a thread that is not backed by a commit confirmed on the remote, or one you have not replied to.
- **NEVER** assign `REJECT` on reasoning alone -- name the command or the read, or take it to the gate.
- **NEVER** treat advisory prose, a reviewer's self-report, or vendor boilerplate as a work item.
- **NEVER** fix anything outside the accepted findings -- including a standards violation you spotted yourself in a file you were already editing.
- **NEVER** delete the PR branch.
- **NEVER** ingest this skill's own prior comments as feedback.
- **ALWAYS** re-read the code at HEAD before judging feedback written against an older commit.
- **ALWAYS** state what was not run -- in the terminal output and in the summary comment.
- **ALWAYS** name the verdict and the reason for every finding not accepted -- in the terminal output and in the summary comment.
- **ALWAYS** reply to every thread you evaluated, whatever the verdict.
