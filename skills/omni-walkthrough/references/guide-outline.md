# Guide outline

The guide is one Markdown file of checkbox steps, read and ticked top to bottom. Use these sections in this order.

## 1. Title and purpose

```markdown
# <Feature area>: hands-on walkthrough

Hands-on tour of every user-facing feature on `<branch>` (PR #<n>), each on its happy path. Follow it
top to bottom; every step uses only what earlier steps set up. Expected results come from <docs/user-guide/x.md |
specs 045-051 | the code>; each section names its source so you can read the full rule when a step
surprises you.
```

## 2. Before you start

Everything the reader does once, before step 1.1, with a checkbox for each action:

- start or reset the app (exact command), and the URL
- the logins: one line per persona, saying what the persona can and cannot do
- how to work with several personas (a private window per persona, or log out between them)
- each input simulator: the command, what it prints, run time and cost, and any expected non-zero exit
- seeded data the walk relies on, only when a seed script creates it deterministically

## 3. Handles

A table the reader fills in as they go. It is defined before step 1.1 and filled by the steps that create records:

```markdown
| Handle | What | Value |
| ------ | ---- | ----- |
| P1 | Fresh referral used for the timeline and field checks | |
| T1 | P1's email thread ID | |
| P2 | Referral that will be auto-declined for the revival check | |
```

## 4. Walk sections

Number sections `1.`, `2.`, ... and steps `1.1`, `1.2`, ... so the reader can say where they stopped. Each section opens with its persona and source, and the settings it assumes when it relies on any:

```markdown
## 2. Edits become proposed changes

Persona: `clerk@localhost`. Source: user guide "Proposed changes".

- **2.1** Capture a referral
  - [ ] Run `make e2e-capture`.
  - [ ] Expect a new prospect ID, a link, and a thread ID in the output.
  - [ ] Write them down as **P1** and **T1**.
- **2.2** Open the new prospect
  - [ ] Open the link for P1.
  - [ ] Expect a **Timeline** with a **Referring attorney email** entry.
- **2.3** Edit a field
  - This sets up the proposal in 2.5.
  - [ ] Press **Edit fields**.
  - [ ] Set **Referring attorney phone** to `555-0100`.
  - [ ] Press **Save changes**.
  - [ ] Expect "Changes saved".
- **2.4** Send a follow-up
  - [ ] Run `make e2e-capture FOLLOWUP=<T1>`.
  - [ ] Expect no new prospect; it takes about 60 s.
- **2.5** See the proposed change
  - [ ] Refresh P1.
  - [ ] Expect under **Proposed changes** the phone with "now 555-0100, proposed ...".
```

A numbered step is a plain bullet with a short label, and each action under it is one checkbox, so the reader never hunts through a sentence for the next button mid-demo.

Note that 2.3 says what it sets up for a later step. A forward note like this explains why a step is there. It is allowed because the reader does not have to act on it or jump to it. A forward *dependency*, where an earlier step can only be done after a later one, is never allowed.

Patterns:

- **Setup step**: its own number and its own "Expect", directly above the first check that needs it.
- **Persona switch**: its own numbered step, with one checkbox each for logging out, logging in as `admin@localhost`, and "Expect the **Settings** menu."
- **Setting changed, then restored**: the restoring step comes after the last check that needs the setting, and says "Restore".
- **Judgment-dependent outcome**: a plain bullet states the miss, with one plain bullet per retry action under it, above the checkbox that expects the result. Every later step can then expect that result:

  ```markdown
  - **3.2** The revival is proposed
    - [ ] Run the capture.
    - If a history-only entry appears instead:
      - Run the capture again with the next name in the sequence.
      - Keep going until **Revival proposed** appears.
    - [ ] Expect **Revival proposed**.
    - [ ] Write down the attempt that showed it as **P3**.
  ```

- **Expected failure**: say so in the step ("the script exits non-zero; that is expected, because the email waits for a match").

## 5. Not walked

The edge behaviours the branch enforces but the walk does not step through: validation errors, permission denials, races, limits, and duplicates. One bullet each, naming the feature, the behaviour, and the test that covers it, or "no test found":

```markdown
- Edit fields: a malformed phone is rejected with "Enter a valid phone number" -- `tests/test_fields.py`
- Revival: a second revival on the same prospect is refused -- no test found
```

## 6. Not covered

Bullets, each naming the feature and the reason it cannot be walked in dev: no simulator, needs a real external system, needs data the tooling cannot produce, or needs an order the walk cannot satisfy. This section and "Not walked" are the only ones where forward or external pointers are acceptable.
