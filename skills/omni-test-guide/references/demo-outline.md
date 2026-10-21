# Demo script outline

A demo script is read by the presenter, not the audience. It has two parts: prep, done alone before the meeting, and the live walk, done in front of people. Use these sections in this order.

## 1. Title and summary

```markdown
# <Product area>: demo script

What you will show: <one paragraph in plain language, naming the three to six moments as outcomes
for the user>. Live time: about <N> minutes. Prep: about <N> minutes, done before the meeting.
```

## 2. Prep (before the meeting)

Checkbox steps, numbered `P.1`, `P.2`, ... They follow every rule of the full guide: handles, setup before use, a persona for each step, and an **Expect** on each.

Prep also covers:

- starting the app and checking it answers;
- every slow or uncertain step, with a repeat-until rule when the outcome is not certain:

  ```markdown
  - [ ] **P.4** Run `make e2e-capture FOLLOWUP=<T1>`. Open N1 from the queue. Expect on its **Timeline** a **Follow-up impact** entry reading
    "Reply received: follow up". If it reads anything else, run the command again until it does (each
    run adds an email to N1's timeline; that is fine to show).
  ```

- logging in each persona the demo uses, each in its own browser profile or window, left open on the right page;
- a final check that every record the demo needs is in the state its moment expects, re-confirming any state a later prep step could have changed.

## 3. The live walk

One section per moment, numbered `1.`, `2.`, ... Each section heading names the outcome, not the feature ("Emails file themselves", not "Inbound correlation"). Each moment has three parts:

```markdown
## 2. Follow-up emails land on the right prospect by themselves

- **Do**: In the queue, open N1.
- **Show**: Point at the **Timeline**: the referring attorney's follow-up sits under the original
  referral. Then point at **History**: "Inbound email attached", matched on the same email thread.
- **Say**: "Nobody filed this. When the referring attorney replied, the system recognised the thread
  and attached the email to the right prospect, and it never overwrote what staff had typed."
```

- **Do** is the exact clicks or keystrokes, with labels in bold and handles in angle brackets.
- **Show** says where on the screen to point, using the exact on-screen words.
- **Say** is one to three sentences about the outcome for the user. Keep it to what the screen shows.

When a live action takes a few seconds, add a **While it runs** line with something to say in the meantime.

## 4. After the demo

Checkbox steps that restore any setting the demo changed. Leave this section out if nothing changed.

## 5. Where this stands (internal audience only)

Three short lists, taken from the inventory and the project's user docs, never invented:

- **Shipped on this branch**: the headline capabilities, one line each.
- **Not available yet**: what the user docs list as coming later.
- **Not shown today**: features that work but were left out of the demo, one line each.
