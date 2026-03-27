# omni.review-pr

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). The user may provide a PR number, a full GitHub PR URL, or scope hints (e.g., "focus on the auth changes", "ignore the test refactoring", "this is a clinical application"). If no PR is specified, auto-detect from the current branch.

## Overview

Perform a comprehensive PR review that combines standards enforcement with logic correctness analysis. This command reads the full PR thread to understand intent before judging the code -- findings are anchored to what the PR is trying to accomplish, not just what the code looks like.

**The primary output of this command is GitHub-native.** You MUST post findings as inline comments on the PR diff and submit a formal review verdict using `gh`. The text shown to the user is a summary of what was posted -- not a substitute for posting. If you complete analysis but do not execute `gh` commands, the review is incomplete.

This command replaces the sequential `brs.review` then `brs.hunt` workflow for GitHub PRs. It applies both analytical lenses in a single pass and delivers feedback directly to GitHub.

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
<Blocker and Critical findings, or "No must-fix findings.">

### Bugs Found
<Logic defects with trigger/impact/fix, or "No defects found.">

### Recommended
<Major findings as a consolidated list grouped by category, or "No recommendations.">

### Verdict
<APPROVE or REQUEST CHANGES with justification>
```

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

## Local Output

After executing all `gh` commands, show the user a brief confirmation of what was posted. This is a summary -- the real review lives on the PR in GitHub.

**Tone**: Direct and terse.

```text
PR:       <owner/repo>#<number> — <title>
Verdict:  <APPROVE|REQUEST CHANGES>
Posted:   <N> inline comments, 1 review
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
