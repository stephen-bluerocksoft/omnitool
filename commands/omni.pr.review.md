# omni.pr.review

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). The user may provide a PR number, a full GitHub PR URL, or scope hints (e.g., "focus on the auth changes", "ignore the test refactoring", "this is a clinical application"). If no PR is specified, auto-detect from the current branch.

## Execution Constraint

Do NOT use the Task tool to delegate work to subagents. Execute all steps sequentially in the main agent context. Subagents default to a lesser model (Composer 2) that degrades quality for judgment-intensive work.

## Overview

Perform a comprehensive PR review that combines standards enforcement with logic correctness analysis. This command reads the full PR thread to understand intent before judging the code -- findings are anchored to what the PR is trying to accomplish, not just what the code looks like.

**The primary output of this command is GitHub-native.** You MUST post findings as inline comments on the PR diff and submit a formal review verdict using `gh`. The text shown to the user is a summary of what was posted -- not a substitute for posting. If you complete analysis but do not execute `gh` commands, the review is incomplete.

This command replaces the sequential `brs.review` then `brs.hunt` workflow for GitHub PRs. It applies both analytical lenses in a single pass and delivers feedback directly to GitHub.

**Local repository**: Before reading files on disk, check out the PR head locally (`gh pr checkout` fetches when needed). After the review is fully posted to GitHub, return to the branch or commit you started from, then delete **that same local branch** — the PR head you checked out for this review (`REVIEWED_BRANCH`) — with `git branch -d` when safe. Do not leave that cleanup to the user as optional "you can delete later" advice; Step 6 performs it (or records skip/failure).

## Instructions

Execute the review as **three sequential phases**. Do NOT skip any phase.

### Phase 1: Fetch and Understand

Before judging code, understand what the PR is trying to do and why.

1. **Determine the PR target** from user input. Supported formats:

   - Full URL: `https://github.com/owner/repo/pull/42`
   - Short reference: `owner/repo#42`
   - Bare number (current repo): `#42` or `42`
   - No input: detect from current branch

   Extract `owner/repo` and PR number. For bare numbers or no input, detect the current repo:

   ```bash
   gh repo view --json nameWithOwner -q .nameWithOwner
   ```

   If no PR number is given, find the PR for the current branch:

   ```bash
   gh pr view --json number,title,state -q .number
   ```

2. **Fetch the full PR** with all metadata and comments:

   ```bash
   gh pr view <number> --json \
     number,title,body,state,author,labels,baseRefName,headRefName,\
     comments,reviewComments,reviews,additions,deletions,changedFiles,\
     createdAt,mergedAt,closedAt
   ```

3. **Fetch the diff**:

   ```bash
   gh pr diff <number>
   ```

4. **Check CI status**:

   ```bash
   gh pr checks <number>
   ```

   Note any failing checks -- they provide signal about known issues.

5. **Fetch linked issues** to understand the "why" behind the PR:

   ```bash
   gh api graphql -f query='
     query {
       repository(owner: "<owner>", name: "<repo>") {
         pullRequest(number: <number>) {
           closingIssuesReferences(first: 10) {
             nodes {
               number
               title
               body
               state
               labels(first: 10) { nodes { name } }
             }
           }
         }
       }
     }'
   ```

   If the GraphQL query fails, parse the PR body for `Fixes #N`, `Closes #N`, or `Resolves #N` patterns and fetch those issues individually:

   ```bash
   gh issue view <number> --json title,body,state,labels
   ```

6. **Build the thread narrative**. Read the PR description, all comments, and all review comments in chronological order. Determine:

   - **Purpose**: What is this PR trying to accomplish? (from description and linked issues)
   - **Scope changes**: Did comments narrow or expand the original scope?
   - **Design decisions**: Were alternatives discussed and a direction chosen?
   - **Outstanding concerns**: Are there unresolved review comments or open questions?
   - **Prior review feedback**: Has this PR been reviewed before? What was requested?

   This narrative drives Phase 2 -- it tells you what to look for and what the author intended.

6a. **Check out the PR head locally** (fetch if needed, then review on that tree). Do this **before** step 7 so full-file reads match the PR.

   1. **Record where to return** after the review:

      ```bash
      STARTING_BRANCH=$(git branch --show-current)
      STARTING_SHA=$(git rev-parse HEAD)
      ```

      If `STARTING_BRANCH` is empty, you were in detached `HEAD`; restore with `STARTING_SHA` later.

   2. **Working tree**: If there are unstaged or staged changes, stop and tell the user to stash, commit, or discard. Do not checkout over a dirty tree without explicit user consent.

   3. **Fetch and checkout** (handles same-repo and fork PRs):

      ```bash
      gh pr checkout <number>
      ```

   4. **Record the local branch name** used for this PR (for cleanup):

      ```bash
      REVIEWED_BRANCH=$(git branch --show-current)
      ```

      If checkout fails, stop and report the error; do not assume the working tree matches the PR.

7. **Read every changed file in full** on the checked-out branch -- not just the diff. Context reveals whether changes are consistent with surrounding code, whether error handling matches existing patterns, and whether file length limits are exceeded.

8. **Gather behavioral context**:

   - Read any governing specification in `specs/` that describes intended behavior for the affected area
   - Read existing tests for the changed code to understand expected inputs, outputs, and invariants
   - Read callers of changed functions to understand how the code is actually invoked
   - Check for type definitions, schemas, or API contracts in `contracts/` that constrain inputs and outputs

9. **Build a file inventory**. List every changed file and classify by type:

   | File Type | Extensions / Patterns | Analysis Focus |
   | --------- | --------------------- | -------------- |
   | Python | `.py` | Security, Performance, Code Quality, Testing, Observability |
   | TypeScript/JS | `.ts`, `.tsx`, `.js`, `.jsx` | Security, Performance, Code Quality, Testing, Accessibility |
   | Markdown | `.md`, `.mdc` | Markdown formatting |
   | Infrastructure | `Dockerfile`, `*.yaml`/`*.yml`, `*.tf`, shell scripts | Security, Infrastructure |
   | C/C++ / Embedded | `.c`, `.cpp`, `.h`, `CMakeLists.txt` | Security, Embedded Systems, Code Quality |
   | Config / Other | `.json`, `.toml`, `.cfg`, `.env*` | Security |

   Note total scope: file count, lines added/removed, overall purpose.

### Phase 2: Analyze

Apply both standards enforcement and logic correctness analysis in a single pass. This phase has four sub-steps that must all complete before proceeding to Phase 3.

#### Step 1: Automated Pattern Scan

Run **every search below** across all changed files. These are deterministic checks -- run them all, record every hit. Do not skip any.

**Security and information leakage**:

| Pattern | What to search | Severity |
| ------- | -------------- | -------- |
| Hardcoded secrets | Strings resembling API keys, tokens, passwords, connection strings, IPs with ports | Blocker |
| Permissive access defaults | Wildcard CORS origins (`*`), disabled auth checks, overly broad permissions | Critical |
| Sleep in prod code | `sleep(` in non-test Python files | Critical |
| Exception details leaked to clients | `HTTPException` with `detail=str(exc)` or response dicts containing `"error": str(exc)` | Critical |
| f-string logging | `logger.info/debug/warning/error/critical(f"` -- must use lazy `%s` formatting | Major |
| Unsafe string templating | `string.Template.substitute(` or `.format(` on user-controlled text | Critical |
| Unvalidated response shapes | `response.json()` accessed with `.get()` or `["key"]` without `isinstance(data, dict)` check | Major |

**Code quality**:

| Pattern | What to search | Severity |
| ------- | -------------- | -------- |
| Debug leftovers | `TODO`, `FIXME`, `HACK`, `XXX`, `console.log`, `print(`, `debugger` | Major |
| hasattr misuse | `hasattr(` in Python files | Major |
| Bare exceptions | `except Exception:` or `except:` without re-raise | Major |
| Swallowed exceptions | `except` blocks containing only `pass` or only a log with no re-raise | Major |
| Inline imports | `import` statements after the first non-import code in Python files | Major |
| Disabled linters | `noqa`, `eslint-disable`, `type: ignore`, `pragma: no cover` without justification | Major |
| Non-reproducible versions | `:latest` tags, unpinned dependencies, wildcard version ranges | Major |

**Resource and lifecycle**:

| Pattern | What to search | Severity |
| ------- | -------------- | -------- |
| Per-call resource creation | HTTP clients, DB connections, or sessions instantiated per-call instead of shared/pooled | Major |
| Timer/listener leaks | `setTimeout`/`setInterval`/`addEventListener` without cleanup | Major |

#### Step 2: Logic and Correctness Analysis

For every changed or new function, method, or endpoint, apply these analytical lenses. Focus attention proportionally -- new code gets full analysis, minor edits to existing code get lighter treatment.

**Execution paths**: Trace every branch (`if`/`elif`/`else`, `match/case`, ternary, loops) from entry to exit. Check:

- Does every path return the correct type?
- Are variables defined on all paths before use?
- Is comparison logic correct (`>` vs `>=`, `and` vs `or`, negation)?
- Are arithmetic operations safe (division by zero, overflow, float equality)?
- Are collection operations safe (missing keys, empty collections, mutation during iteration)?

**Boundary conditions**: For each input, mentally trace boundary values through the function:

- Numeric: `0`, `-1`, `MAX`, `NaN`
- String: `""`, very long, unicode, special characters
- Collection: `[]`/`{}`, single element, contains `None` elements
- Optional: `None`/`null`, missing key, unset env var

**Fault paths**: At every external interaction (network, file I/O, database, subprocess), ask "what if this fails?" Check:

- Is the call wrapped in appropriate error handling?
- Are resources cleaned up on failure?
- Does the error propagate correctly with useful context?
- Can cascading failures occur (service A fails, code still calls service B with bad data)?

**Concurrency** (if applicable): Identify shared mutable state and check:

- Missing locks or atomic operations on read-modify-write
- Missing `await` on coroutine calls
- Blocking calls inside async functions
- State machine transitions that can conflict under concurrent requests

**Integration seams**: Check contracts at every boundary:

- Does the caller pass arguments in the right order, types, and units?
- If a callee's signature changed, were all callers updated?
- Does the implementation match API contracts in `contracts/` or OpenAPI specs?
- Are serialization assumptions correct (datetimes, enums, Decimals)?

#### Step 3: Per-File Deep Review

For **each** changed file in the inventory, in order:

1. Read the full file (already done in Phase 1, but re-focus on it now)
2. Re-read the diff for that specific file
3. Apply pattern scan findings from Step 1 and logic analysis from Step 2
4. Check against the PR's stated intent from the thread narrative -- does this change accomplish what it claims?
5. Record each finding with: file path, line number, severity, confidence score (1-10), issue, and fix

**Confidence scoring** (applies to all non-pattern-scan findings):

| Score | Meaning |
| ----- | ------- |
| 9-10 | **Certain.** Verifiable from the code alone. Any reviewer would flag this. |
| 7-8 | **High confidence.** Clear from the code in context. A senior engineer would flag this. |
| 5-6 | **Moderate.** Depends on runtime behavior or configuration assumptions. |
| 1-4 | **Low/Speculative.** Plausible but context outside the code may prevent it. |

**Reporting threshold: 7/10.** Only findings scoring 7 or above survive to the output. Pattern scan findings are exempt -- they are deterministic.

**Reporting tiers**: Findings are routed by severity to minimize noise on the PR diff:

- **Blocker / Critical**: Posted as inline comments on the PR diff (Step 4) AND listed in the review body (Step 5)
- **Major**: Included only in the review body "Recommended" section as a consolidated list -- no inline comments

**Priority ordering**: Review security-sensitive files first (auth, config, Dockerfile, infrastructure manifests).

**Scope discipline**: All findings must be relevant to the changed code. Do not flag issues in unchanged surrounding code.

#### Step 4: Cross-Cutting Analysis

After all files are individually reviewed, check for issues that span multiple files:

- New functions/endpoints/classes without corresponding test coverage
- API endpoint changes without documentation or contract updates
- Model/schema changes without migration files
- Inconsistent patterns across changed files (naming, error handling, logging style)
- Spec compliance: if `specs/` exists, verify changes align with the governing specification
- Import or dependency additions without manifest updates
- Changes to shared utilities that could break callers outside the diff
- Directory structure: directories with >10 Python modules need sub-packages
- Test layout: `tests/` structure should mirror source layout

### Phase 3: Verify and Submit to GitHub

**This phase is mandatory. You MUST execute `gh` commands to post findings to the PR. Do NOT skip this phase or treat it as optional. The analysis is worthless if it stays in your context window instead of reaching GitHub.**

#### Step 1: Self-Verification

Before posting anything to GitHub, verify every finding:

1. **Re-read each finding** at the cited code location with fresh eyes. Confirm it is real and actionable.

2. **Apply the reporting threshold**: Remove all non-pattern-scan findings scoring below 7/10.

3. **False positive filter**: For each finding, check whether:
   - A caller or framework prevents the problematic input from reaching this code
   - A test already covers this scenario
   - Surrounding code handles the failure in a way you missed on first read
   - The PR author addressed it in a comment

4. **Severity accuracy**: Blockers must truly block merge. Do not inflate or deflate.

5. **Actionability**: Every finding MUST require a concrete code change. Drop observations, style preferences, and theoretical concerns.

6. **Deduplication**: If the pattern scan and logic analysis both flagged the same issue, keep only one.

7. **Systemic pattern grouping**: If 3+ findings share the same root cause, collapse them into a single systemic finding referencing all locations.

#### Step 2: Determine the Verdict

Based on verified findings, determine the verdict NOW -- you need it for Step 4.

- **REQUEST CHANGES**: One or more Blocker or Critical findings exist, OR one or more Critical/Confirmed bugs exist
- **APPROVE**: No Blocker or Critical findings. Major findings may exist -- they are advisory and do not block

#### Step 3: Get the HEAD Commit SHA

Run this command and store the result. You need it for every inline comment.

```bash
gh pr view <number> --json headRefOid -q .headRefOid
```

#### Step 4: Post Inline Comments to GitHub

**Post inline comments only for Blocker and Critical findings.** Major findings are reported in the review body (Step 5), not as inline comments. Execute a `gh api` command for each Blocker or Critical finding that maps to a specific line in the diff.

For each Blocker or Critical finding with a file path and line number, execute:

```bash
gh api repos/<owner>/<repo>/pulls/<number>/comments \
  -f body="**[Severity]** Issue description.

Fix: suggested change." \
  -f commit_id="<SHA from Step 3>" \
  -f path="<file path relative to repo root>" \
  -F line=<line_number> \
  -f side="RIGHT"
```

**Important constraints for inline comments:**

- The `line` must be a line that appears in the diff. If the finding references a line not in the diff, use the nearest changed line in the same function or include it in the review body instead.
- The `path` must be relative to the repository root (e.g., `backend/invoices/views_reports.py`, not an absolute path).
- The `body` should be concise: state the issue, the severity, and the fix. Do not write essays.
- For systemic findings spanning multiple files, post on the first occurrence and list other locations in the body.
- You may batch multiple findings by running several `gh api` commands sequentially or in parallel.

If a finding cannot be tied to a specific diff line (cross-cutting concerns, test coverage gaps, architectural issues), include it in the review body in Step 5 instead.

#### Step 5: Submit the Overall Review to GitHub

**You MUST execute this command.** Compose a review body summarizing the findings and submit it.

The review body should follow this structure:

```text
## PR Review: <title>

### Summary
<2-3 sentences: what the PR does, overall assessment>

### Must Fix
<One short line per Blocker/Critical: what is wrong and where. If full trigger/impact/fix
for a logic bug lives under Bugs Found, do not repeat that narrative here — only a headline.>

### Bugs Found
<ONLY when logic/behavior defects need a trigger/impact/fix story. Omit this entire section
when Must Fix is sufficient on its own, when there are no defects, or when it would only
repeat Must Fix in longer form (pick one depth per finding — not both).
Never use this section for positive commentary on correct code.>

### Recommended
<Major findings as a consolidated list grouped by category, or "No recommendations.">

### Verdict
<APPROVE or REQUEST CHANGES with justification>
```

**Must Fix vs Bugs Found** (dedupe and depth):

1. Every Blocker and Critical **must** appear in **Must Fix** (even if also a logic bug).
2. **Bugs Found** is optional. Use it only for logic/behavior defects where **trigger, impact, fix** adds clarity beyond a one-liner.
3. **Do not duplicate** the same finding at full depth in both sections. If you use **Bugs Found** for an item, keep the matching **Must Fix** line to a **headline** (name the defect; no second full explanation). If the issue is clear from a short **Must Fix** line alone, **omit Bugs Found** for that item — and **omit the entire Bugs Found section** when nothing needs the long form.
4. Blocker/Critical findings that are **not** logic bugs (e.g. hardcoded secret, policy violation) belong in **Must Fix** only — not again under **Bugs Found**.

Execute the appropriate command:

**If REQUEST CHANGES:**

```bash
gh pr review <number> --request-changes --body "$(cat <<'EOF'
<review body here>
EOF
)"
```

**If APPROVE:**

```bash
gh pr review <number> --approve --body "$(cat <<'EOF'
<review body here>
EOF
)"
```

**After submitting**, confirm to the user what was posted.

#### Step 6: Restore previous branch and delete local review branch

After all review `gh` commands in this phase succeed:

1. **Checkout the starting ref**:

   - If `STARTING_BRANCH` is non-empty: `git checkout "$STARTING_BRANCH"`
   - If `STARTING_BRANCH` is empty (detached at start): `git checkout "$STARTING_SHA"`

2. **Delete the local PR head branch used for this review** (`REVIEWED_BRANCH` — the branch `gh pr checkout` put you on; the local copy of the branch this PR is from). That is the branch to remove, not some other ref. Use `git branch -d` when `REVIEWED_BRANCH` is non-empty:

   ```bash
   git branch -d "$REVIEWED_BRANCH"
   ```

   **Skip `git branch -d`** when:

   - `REVIEWED_BRANCH` is empty (`gh pr checkout` left detached `HEAD` -- there is no local branch name to delete)
   - `REVIEWED_BRANCH` equals `STARTING_BRANCH` (you started on the PR head; removing it would delete the branch you were already using)

   If `git branch -d` refuses because the branch is not fully merged, report Git's message and leave the branch in place. Do not use `git branch -D` unless the user explicitly asks to force-delete.

3. **User-facing summary (Git)**: State the **exact branch name** `REVIEWED_BRANCH` when reporting deleted / skipped / left. Example: `Deleted local review branch 047-datastore-mcp-server` or `Left branch 047-datastore-mcp-server: not merged`.

   **Do not** tell the user they may delete the PR branch "later" with `git branch -D <name>` as generic housekeeping. Step 6 already performed cleanup or explained why the branch remains. Suggesting redundant manual deletion contradicts the workflow and reads as if the command did not remove the checkout branch.

## Local Output

After executing all `gh` commands, show the user a brief confirmation of what was posted. This is a summary -- the real review lives on the PR in GitHub.

**Tone**: Direct and terse.

**Git line**: Must match Step 6 — include **`REVIEWED_BRANCH` by name** (e.g. `Deleted REVIEWED_BRANCH`, `Skipped delete (started on same branch)`, `Left REVIEWED_BRANCH: not merged`). Never add a separate suggestion to remove the PR head branch later with `-D`; that duplicates or overrides Step 6.

```text
PR:       <owner/repo>#<number> — <title>
Verdict:  <APPROVE|REQUEST CHANGES>
Posted:   <N> inline comments, 1 review
Git:      Restored to <branch or detached SHA>; <deleted|skipped|left> local review branch <REVIEWED_BRANCH>: <reason if needed>
```

### Inline Comments Posted

```text
<file>:<line> — [Severity] <short description>
<file>:<line> — [Severity] <short description>
...
```

### Findings Included in Review Body

List Major findings and any cross-cutting findings that were included in the `gh pr review` body:

```text
- [Major] <description>
- [Major] <description>
```

If no findings were routed to the review body, write: "No review body findings."

### Link

Provide the PR URL so the user can view the review:

```text
https://github.com/<owner>/<repo>/pull/<number>
```
