# Global Defaults

Universal workflow defaults that apply to every project.

- Scratch work goes in the session scratchpad when the harness provides one, otherwise in the repository's gitignored `temp/`. Files a person will reopen -- reports, issue drafts, plans -- go in `temp/`.
- Spec work goes through `/omni-spec-create`, `/omni-spec-modify`, `/omni-spec-align`, and `/omni-spec-implement`, which wrap the BRS spec agents. In a Speckit repository, implement through `/omni-spec-implement`, never by hand.
- A subagent's "done" is a claim: check its files, logic, and test run yourself before marking the task complete.
