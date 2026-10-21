# Guide outline

The guide is one Markdown file of checkbox steps, read and ticked top to bottom. Use these sections in this order.

## 1. Title and purpose

```markdown
# <Feature area>: hands-on walkthrough

Hands-on walk through every user-facing feature on `<branch>` (PR #<n>). Follow it top to bottom;
every step uses only what earlier steps set up. Expected results come from <docs/user-guide/x.md |
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
## 2. Editing fields and proposed changes

Persona: `clerk@localhost`. Source: user guide "Proposed changes".

- [ ] **2.1** Run `make e2e-capture`. Expect a new prospect ID, a link, and a thread ID in the
  output. Write them down as **P1** and **T1**.
- [ ] **2.2** Open the link for P1. Expect a **Timeline** with a **Referring attorney email** entry.
- [ ] **2.3** Press **Edit fields**, set **Referring attorney phone** to `555-0100`, and press
  **Save changes**. Expect "Changes saved". This sets up the proposal in 2.5.
- [ ] **2.4** Run `make e2e-capture FOLLOWUP=<T1>`. Expect no new prospect; it takes about 60 s.
- [ ] **2.5** Refresh P1. Expect under **Proposed changes** the phone with "now 555-0100, proposed
  ...".
```

Note that 2.3 says what it sets up for a later step. A forward note like this explains why a step is there. It is allowed because the reader does not have to act on it or jump to it. A forward *dependency*, where an earlier step can only be done after a later one, is never allowed.

Patterns:

- **Setup step**: its own checkbox and its own "Expect", directly above the first check that needs it.
- **Persona switch**: `- [ ] **3.1** Log out, then log in as \`admin@localhost\`. Expect the **Settings** menu.`
- **Setting changed, then restored**: the restoring step comes after the last check that needs the setting, and says "Restore".
- **Judgment-dependent outcome**: "Expect one of **Revival proposed** or a history-only entry; write down which." The next step works either way.
- **Expected failure**: say so in the step ("the script exits non-zero; that is expected, because the email waits for a match").

## 5. Not covered

Bullets, each naming the feature and the reason it cannot be walked in dev: no simulator, needs a real external system, needs data the tooling cannot produce, or needs an order the walk cannot satisfy. This is the only section where forward or external pointers are acceptable.
