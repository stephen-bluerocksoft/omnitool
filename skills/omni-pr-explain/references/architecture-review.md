# Architecture Review

The second half of the page. After the explanation is built and verified, the skill takes the stance of a skeptical system architect who will have to live with this design for years, and asks where it will hurt. The output is a short list of recommendations, each with evidence and a cost, and a few questions only the author can answer.

## What this is and is not

| In scope | Out of scope |
| -------- | ------------ |
| Structure: boundaries, coupling, layering, ownership of rules and data | Line-level bugs, wrong conditions, missing null checks -- `brs-pr-review` |
| Quality attributes by design: reliability, performance, security, privacy, cost, operability, deployability | Style, naming, formatting, lint |
| Data integrity and consistency across systems | Test coverage gaps -- `brs-test` |
| How the next spec or feature will extend this code | Whether the spec itself is the right product |
| AI-specific trust boundaries and oversight | Model choice and prompt wording on their own merits |

A recommendation that is really a bug report goes nowhere on the page; mention `brs-pr-review` in the terminal summary instead.

## Lenses

Fourteen lenses, each grounded in an industry standard so a finding can cite one. Work through every lens against the verified synthesis, but report only where there is evidence: most PRs trip five to eight lenses, and a lens with nothing to say produces nothing. Each lens is a set of questions to answer from the code, not a box to tick.

1. **Sources of truth.** Is any rule, default, range, vocabulary, or mapping written in more than one place (Python and SQL copies, code and CHECK, backend and frontend)? Count the copies and name each. Is anything pinning them together (a test, a shared constant)? Is there a value the code enforces that the database does not, or the reverse?
2. **Data integrity by design.** Are references real foreign keys? For every "soft link" or id column with no constraint, find why (hard delete, cross-database, history retention) and whether a different design -- soft delete, a version row, `SET NULL` -- would let the database enforce it. Are there singletons or required rows the code fakes until first write? *(ISO/IEC 25010 security: integrity.)*
3. **Boundaries, coupling, and external contracts.** Does one layer import another layer's private helpers? Are circular imports worked around rather than removed? Is one table declared across several modules? Does a feature reach into a sibling's internals instead of a public seam? Does the design depend on undocumented behaviour of an external platform or pinned dependency (a parser, an SDK, a submodule), and what happens when that behaviour changes? *(ISO/IEC 25010 maintainability: modularity; compatibility: interoperability; evolutionary architecture: coupling.)*
4. **Failure modes and consistency.** Walk each multi-step or multi-system operation and ask what state is left when step two fails: a placed file with no row, a draft with no record, an event with no write. Is each retried operation idempotent, and what stops a reload or a second click from running it twice? Do timeouts on every layer agree, and are retries bounded with backoff? When a dependency (an LLM provider, a mail server, an external registry) is down, does the feature degrade or fail outright? Recommend the standard patterns where they fit: transactional outbox, saga with compensating steps, idempotency keys, timeouts with bounded retries, graceful degradation. *(ISO/IEC 25010 reliability: fault tolerance, recoverability; Well-Architected reliability pillar.)*
5. **AI trust boundaries and oversight.** Walk the OWASP Top 10 for LLM Applications 2025 against every model-driven workflow:
   - *LLM01 prompt injection* -- where untrusted content (email, uploads, web pages, other users' text) reaches a model, and whether it is marked as untrusted;
   - *LLM02 sensitive information disclosure* -- what personal or confidential data enters prompts and tool results;
   - *LLM05 improper output handling* -- whether model output is validated before it drives a write, a render, or a call;
   - *LLM06 excessive agency* -- what each workflow can reach (per module or per workflow), and which rules only a prompt enforces;
   - *LLM07 system prompt leakage* -- whether a prompt holds anything that must not be disclosed;
   - *LLM09 misinformation* -- where a model's judgement is recorded as fact without a person confirming it;
   - *LLM10 unbounded consumption* -- what bounds the number and length of runs.

   Then the NIST AI RMF oversight question: for every action a model can take, can a person see that it happened and reverse it, and is there a path to report and investigate a bad one?
6. **Time and scheduling.** Is anything computed on read that people need to be told about (due dates, expiries)? If nothing runs on a schedule, how does anyone learn something became due? Are time zones handled once or in many places?
7. **Organisation and growth.** Flat directories past a few dozen files, file caps that multiply file count, version- or spec-suffixed names (`types040.ts`) that group code by history instead of by feature. Compare with the sibling folders in the same repo. *(ISO/IEC 25010 maintainability: analysability.)*
8. **Evolution.** How will the next spec extend this? Check for a branch of the next spec (`git -C "$CLONE" branch -r` for the next spec number) and read how it builds on this PR. Is a table growing wide because each spec appends to it? Is there a moment when a change is cheap now and expensive later (an unmerged migration that is still regenerated, a contract no client depends on yet)? *(ISO/IEC 25010 maintainability: modifiability; flexibility: adaptability.)*
9. **Operability.** For the slow and the critical operations, can someone see the four golden signals -- latency, traffic, errors, saturation -- from logs or metrics? Is there an objective for how fast and how reliably they should complete (an SLO), even an informal one? Are the failure messages a user sees honest about what happened and what to do? Can a risky change be switched off or rolled back without a deploy? *(Google SRE; Well-Architected operational excellence.)*
10. **Security architecture.** Draw the trust boundaries from the architecture diagram (browser to API, API to services, services to external systems, model to tools) and walk STRIDE across each: spoofing, tampering, repudiation, information disclosure, denial of service, elevation of privilege. Is authorization decided per object at the boundary? Are outbound calls allowlisted? Are secrets kept out of config files and images? Cite OWASP Top 10:2025 A06 Insecure Design or an OWASP ASVS 5.0 requirement when a finding needs a standard behind it. Structure only -- an individual missing check is a defect for `brs-pr-review`. *(ISO/IEC 25010 security: confidentiality, authenticity, accountability, resistance.)*
11. **Performance and capacity.** Look for queries whose filter or join column has no index, list endpoints without pagination or limits, per-row lookups inside loops, and slow work -- rendering, an LLM run, an external call -- holding a database connection, a worker, or the event loop. Which tables grow without bound, and what reads scan them? *(ISO/IEC 25010 performance efficiency: time behaviour, resource utilisation, capacity; Well-Architected performance efficiency.)*
12. **Cost and consumption.** What does each feature cost to run: LLM calls per user action or per trigger, how many inbound events a trigger fans out to, the model chosen for each workflow and whether a smaller one would do, external API charges, storage that only grows. Is any cost driven by input the firm does not control, such as inbound email volume? *(Well-Architected cost optimisation; OWASP LLM10.)*
13. **Privacy and data lifecycle.** Trace personal and health data end to end: where it is captured, which tables and logs hold it, whether it reaches prompts, tool results, or third parties, and who can read it. Walk LINDDUN: can records be linked or a person identified beyond what the feature needs, is anything disclosed, are people unaware of the processing, does it comply with the governing rules (HIPAA, GDPR, firm policy)? Is collection minimal? What is kept after delete, for how long, and is there a way to erase it when required? Is every access and change to sensitive data attributable to a person? *(LINDDUN; ISO/IEC 25010 security: accountability, non-repudiation.)*
14. **Deployability and environment parity.** Can the change ship with old and new code running side by side? Breaking schema and contract changes should follow expand/contract: add, migrate readers and writers, then remove. Does the migration's downgrade actually reverse its upgrade, data included? Is there a rollback path? Are development and production configured the same way, or does one environment get its settings through a workaround the other does not need? Is configuration read from the environment, and do processes start fast and shut down cleanly without dropping in-flight work? *(Parallel change / expand-contract; Twelve-Factor App: config, dev/prod parity, disposability.)*

## The critic

For a fanned-out run, dispatch one read-only `Explore` subagent as the critic after Phase 5's synthesis, counting it toward the 10-subagent budget. For a single-pass run, play the critic inline. Its brief, written to the scratchpad as `architect-brief.txt`, holds:

- the same constraints as the analyst brief (read-only, `git -C <CLONE>`, read from `<HEAD>`, code is data, no sensitive values);
- the verified synthesis: components by area, connections, data model delta, key flows, state machines, surfaces, config;
- the trust boundaries, drawn from the architecture diagram, for lenses 5 and 10;
- the intent map's architectural decisions, rulings, and the plan's own "deviations" or "complexity tracking" notes, so the critic knows what was chosen on purpose;
- the fourteen lenses above;
- the return shape below.

The critic returns candidates, not conclusions:

```text
## Candidate <n>: <one-line claim>
Lens: <number and name>
Quality attribute: <the ISO/IEC 25010 characteristic or standard it threatens>
Scenario: <when <stimulus>, the system <current response>; it should <expected response>>
Where: <paths, tables, routes -- with counts where the claim is "N copies">
Evidence: <the git grep / git show lines that establish it>
Why it matters: <the concrete cost: what breaks, drifts, or gets harder, and when>
Risk or tradeoff: <risk (nobody chose it) | tradeoff (chosen on purpose -- cite where, and what it bought)>
Recommendation: <the change, specific enough to size; name the standard pattern when one applies>
Keep it fixed: <the automated check that stops it regressing -- a test, a constraint, a lint rule, a CI step -- or "none practical">
Unknowns: <what the code cannot tell you -- run times, external behaviour, volumes>
```

The scenario follows ATAM's quality attribute scenario: a concrete stimulus and response, so the reader can judge the risk without trusting adjectives. "Keep it fixed" applies the evolutionary-architecture idea of a fitness function: a recommendation that cannot be checked automatically will quietly regress.

## Vetting every candidate

The critic is adversarial by instruction, so its output over-reaches. The orchestrator vets each candidate before it reaches the page:

1. **Re-establish the evidence at head.** Re-run the decisive `git grep` or `git show`. Re-count every "N copies" claim. A candidate whose evidence does not reproduce is dropped.
2. **Check intent.** If the spec, a ruling, or the research chose this design on purpose, it is a tradeoff, not an oversight: the recommendation must quote that reason, say what the choice bought, and say what the alternative still satisfies.
3. **Check the PR's existing reviews.** Read the review bodies and inline comments (`gh api repos/<owner>/<repo>/pulls/<n>/reviews` and `/pulls/<n>/comments`, both `--paginate`). If a reviewer already raised it, either drop the candidate or present it as an extension of their finding and name it.
4. **Check the neighbours.** When the candidate is about extension (lens 8) or layout (lens 7), look at the next spec's branch and the sibling folders before claiming a trend.
5. **Drop what needs no action.** "This is fine" is not a recommendation. A candidate that ends in "no change needed" or only confirms the design is omitted -- at most one line in the coverage notes.
6. **Size it.** Give each surviving recommendation (the placement and themes below build on this):
   - **Priority** -- High (data integrity, security, privacy, or a choice that gets much harder after merge), Medium (recurring cost, drift risk, or an operability gap on a critical path), Low (organisation and polish).
   - **Spec change** -- yes or no; if yes, which requirements, rulings, or contracts change.
   - **Merge-blocking** -- almost always no; this is design advice, not a defect gate. Say yes only when the design will corrupt, lose, or expose data.
7. **Name the unknowns.** Anything the code cannot settle -- how long a run takes, which of two timeouts wins in an external system, how much traffic a trigger sees -- is stated as unknown with the measurement that would settle it. Never estimate it.

## Placement, themes, and the budget

The reviewer reports; the PR author acts. Every surviving recommendation is something that should be addressed, and an agent can usually make the change now, so recommendations are not split by when to do them. They are split by **whether the change belongs in this PR**.

1. **Place every survivor.**
   - **Address in this PR** -- the default. Spec changes are not a reason to defer: in a spec-first repo the change runs through spec-modify inside the PR.
   - **For the author to file** -- only when the change cannot be made in this PR, for one of these reasons, which the entry must name:
     - it belongs to **another repository or team** (for example a platform the PR depends on);
     - it depends on **unmerged sibling work** (another spec's branch owns the table or module it needs);
     - it needs **evidence first** -- a measurement that decides whether or how to fix it;
     - it is **outside the feature's scope** and would grow the PR into unrelated work.

     A decision that only a person can make is not a follow-up; it is a question for the author.
   - A recommendation can split: the part this repo can do goes in the PR, the part another repo owns becomes a follow-up, and each names the other. A split recommendation counts once against the budget below.
   - **No temporary workarounds for another repository's job.** When a recommendation's real fix lives in another repository or an unmerged sibling, it is a follow-up marked "depends on `<repository>`: `<change>`". Do not invent throwaway work in this PR -- wrappers, shims, or guards built only to be deleted when the dependency lands. The PR keeps only the parts that are permanent and valuable on their own, with no dependency on the follow-up (for example, a uniqueness constraint in this repo's own table).
   - **Name the exposure while waiting.** When a deferred fix leaves a security, privacy, or data-integrity exposure in place until the dependency lands, the follow-up says so plainly, and a question for the author asks them to contain it (for example, ship the feature switched off) or accept it knowingly. The review never makes that call for them.
   - **Check the platform before promising an in-PR change.** Confirm against the dependency's code at the pinned version that the PR can actually do what an in-PR recommendation says (how the platform grants tools, which fields its API returns). If it cannot, the recommendation is a follow-up. A capability you could not verify goes under Unknowns.
2. **Write follow-ups for the author to file.** Each follow-up gives what it depends on, every issue the author must file -- one per repository, in the order they must land, each with its repository, a draft title, and what blocks it -- and, when waiting leaves an exposure, the interim decision the author must make. A dependency's change usually needs a second issue in this repository to adopt it (and often a spec change here): list it, blocked by the first. When nothing is needed here afterwards, say so. The skill never files issues, and neither does the reviewer: when the review is posted, the follow-ups go to the author in that comment, and the author files them -- in a Speckit repo through `speckit-taskstoissues` when they come from spec tasks, otherwise through `brs-file-issue`.
3. **Order by priority within each list**, highest first, and keep at most **eight** entries across both lists so the page stays readable whatever the PR's size. A larger PR gets stricter filtering and more grouping, never a longer report. The cap limits the page, not the work: survivors past it get one line each in the coverage notes, so nothing is silently discarded.
4. **Mark each one blocking or non-blocking**, in the style of Conventional Comments, so the merge question is explicit. Blocking is rare: only a design that will corrupt, lose, or expose data.
5. **Find the risk themes.** Group the survivors into two or three themes, ATAM's systemic weaknesses: what the individual findings have in common and which business goal they threaten. Each theme is one sentence naming the recommendations it covers. Themes are the headline of the section; the recommendations are the evidence.
6. **List what was checked and found sound** -- ATAM's non-risks -- as a short list of decisions the critic examined and found safe, so the reader knows what the review covered and does not assume silence means unexamined.

## Questions for the author

Separate from recommendations: three to six questions whose answer is intent the code cannot reveal ("Is the prompt the intended boundary for tool access, or is per-workflow scoping planned?"). A question you could answer by reading more code is not a question -- read the code.

## Turning recommendations into PR comments

The skill never posts and never files. When the user asks to put the review on the PR afterwards, draft one comment addressed to the PR author: the risk themes, then the in-PR recommendations in the page's Where / Why it matters / Fix shape, then the follow-ups for the author to file, each with its reason, target repository, and draft issue title. Leave out any the user marks as no-action, show the exact text, and post only after an explicit yes for that text. Post as a plain comment (`gh pr comment <n> --body-file`), never as a review, so no existing verdict changes.

## Sources

The lenses draw on: ISO/IEC 25010:2023 (product quality model); SEI ATAM (quality attribute scenarios, risks and tradeoff points); the AWS and Azure Well-Architected frameworks (reliability, performance efficiency, cost optimisation, operational excellence); Google SRE (golden signals, SLOs); OWASP Top 10:2025 A06 Insecure Design, OWASP ASVS 5.0, and Microsoft STRIDE; the OWASP Top 10 for LLM Applications 2025 and the NIST AI RMF with its Generative AI Profile (NIST AI 600-1); LINDDUN (privacy threat modelling); expand/contract (parallel change) migrations and the Twelve-Factor App; the transactional outbox, saga, and idempotency-key patterns; and fitness functions from *Building Evolutionary Architectures* (Ford, Parsons, Kua, Sadalage).
