# Running and recording a guide

How Phase 10 drives a guide in a real browser and records it. Everything here lives under the project's gitignored `temp/walkthrough/`.

## Files

| File | Written by | Purpose |
| ---- | ---------- | ------- |
| `temp/walkthrough/<guide-name>-prep.py` | You, when the guide has setup beyond starting the app | Does the setup and undoes it through the app's API |
| `temp/walkthrough/video/recorder.mjs` | Copied from this skill's `scripts/` | The browser, the video, the captions, and the log |
| `temp/walkthrough/video/<guide-name>.mjs` | You | The driver: the guide's steps as code |
| `temp/walkthrough/video/out/` | The take | `<name>.webm`, `.log`, `.results.json`, `<name>-frames/`, and downloaded files |

## Install

From `temp/walkthrough/video/`, once:

```bash
npm init -y
```

```bash
npm install --no-audit --no-fund --save-exact playwright-core@1.64.1
```

```bash
npx playwright-core install --no-shell --no-remove chromium ffmpeg
```

Keep `--no-remove`: without it, Playwright deletes browsers that other installations on the machine still use. Copy `scripts/recorder.mjs` from this skill into the same directory, because an import of `playwright-core` resolves from the importing file's directory, not from the working directory. The version is pinned because its license was read at that version (`Apache-2.0`); a new version gets the same read first. The ffmpeg Playwright installs is an LGPL program that the recorder runs as its own process, unmodified, through a pipe.

## Prep script

Write one when the guide's setup is more than starting the app, in the standard library of a language the project already uses. Copy the shape of what makes it safe to repeat:

- `prep --run <TAG>` and `restore`. The run tag goes into every name and email it creates, so a take never collides with leftovers from earlier takes and a list search finds exactly this run.
- **Talks to the app's API as the dev logins.** Reach the database only for what no API can do, such as moving a deadline into the past, and with bound values. State the local base URL in one constant and refuse any other scheme.
- **Refuses early.** Check every prerequisite before the first change (seeded templates, a required group), and say the command that supplies it. A missing prerequisite then costs one second, not a failed take at step 3.
- **Saves before it changes.** Write the values it will replace to a state file before the first change, so a prep that fails part way can still be restored. It refuses to run while a state file exists.
- **Gives each record the data later steps need.** Rehearsal is what proves this: a package that needs a date of birth stops the walk if prep left it out.
- **Skips no moment.** Prep may use a status override or a similar shortcut to reach a moment's starting state. It never produces the result a moment exists to show.

Seed commands can undo prep (a seed that resets group grants, for example). Find this in Phase 3, and say in the guide which one runs first.

## Driver

One function per guide section, in guide order, using only `Take`'s methods. The guide is the source: a caption opens with the step's number, each **Expect** becomes one `see` or `check` with the guide's wording, and each action becomes one call.

```javascript
import { readFileSync } from 'node:fs';
import { Take, runTake } from './recorder.mjs';

const argument = (name) => { const i = process.argv.indexOf(`--${name}`); return i < 0 ? undefined : process.argv[i + 1]; };
const RUN = argument('run');
const REPO = new URL('../../../', import.meta.url).pathname;
const APP = 'http://localhost:8888';
const PREP = 'temp/walkthrough/feature-demo-prep.py';
const take = new Take({ out: `${REPO}temp/walkthrough/video/out/feature-${RUN}`, cwd: REPO });
let handles;

async function prep() {
  await take.goto(APP);
  await take.cap('P.1 Run the prep script');
  await take.shell('python3', [PREP, 'prep', '--run', RUN], { ms: 7000 });
  handles = JSON.parse(readFileSync(`${REPO}temp/walkthrough/demo-prep-state.json`, 'utf8')).handles;
}

async function moment1() {
  await take.cap('1.1 Request the records', 2500);
  await take.goto(`${APP}/items/${handles.H1}`);
  await take.press('Record request');
  await take.type('Reason', 'Need the clinic records');
  await take.press('Record request');
  await take.see('Waiting for records', { within: take.page.locator('header').first() });
}

async function after() {
  await take.cap('A.1 Restore the settings');
  await take.shell('python3', [PREP, 'restore'], { ms: 3000 });
}

const only = argument('moments')?.split(',');
process.exit(await runTake(take, [['P', prep], ['1', moment1], ['A', after]], only));
```

Give every numbered step its own `cap`, even one with no action, so it appears in the results.

**Getting a selector right.** On a failure, `runTake` prints what was on screen and saves `<out>-fail.png`; read those before changing anything. Patterns that recur:

- Limit a status check to the region that shows the current status (`within`), or it matches the same words in a history list.
- A field's contents are not text on screen: read `inputValue()` and use `check`. The same goes for the options of a native `select`.
- `see` matches visible text only, so a hidden option never satisfies it.
- A name that appears on both a page and its dialog: `press` takes the last match, the dialog's confirm. Pass `first: true` for the button that opens the dialog.
- Stay in one tab, because only the first tab is recorded. For a link that opens a new tab, read its address and use `take.goto`.
- A file the guide says is produced is checked by its contents, not by the download finishing. Show it with `panel`, or with `image` for a PDF page rendered by a tool the project already has.

## Waits and retries

Use `waitOff` for anything slower than a few seconds. It stops the recording, polls, resumes, and writes the wait into the caption, so no cut is silent. `shell` also stops the recording while its command runs.

The guide's repeat-until loops have no cap, because a person is watching. A driver's do: at most three retries, each logged as `retry`, and then the take fails. Before retrying a paid run, read why it missed. The same error twice, such as a provider refusing for lack of credit, is an environment problem that a retry only pays for again.

## Rehearse, then one clean take

1. Run the moments one at a time with `--moments P,1`, each with a new run tag. Moments that repeat paid runs are rehearsed only as often as it takes to get them right.
2. Sort every failure, and act on it by what it is:

   | The failure is | Do this |
   | -------------- | ------- |
   | A wrong selector in the driver | Fix the driver |
   | The guide says something the app does not do, and the app is right | Fix the guide, and tell the person each change |
   | Prep left out something a step needs | Fix prep |
   | The app does not do what its spec says | Stop and report it; this skill never edits tracked files |
   | The environment is blocked: credits, a container, a credential | Stop and ask |

   Never loosen an **Expect** to get a pass, and never skip a step.

3. Delete the rehearsal outputs, restore, and run the whole guide once with a new tag. That is the take you report. A take that retried, or fixed itself along the way, is fine as long as the log shows it. If the driver changes after it, it is no longer the take of record: run it again.

## Confirm the take

A green take shows only that the screen said the right words. Check three more things before reporting it:

- **Step coverage.** Every numbered step in the guide ran:

  ```bash
  comm -23 <(grep -oE '^- \*\*[A-Z0-9]+\.[0-9]+\*\*' <guide> | tr -d '*' | cut -c3- | sort -u) \
    <(node -p "[...new Set(require('./out/<name>.results.json').map((r) => r.step))].join('\n')" | sort -u)
  ```

  It prints the steps that did not run. A step that is reference only, such as a list of personas, is fine to leave; name each one in the report.

- **The real thing ran.** For each step that starts background work, confirm it from the app's own record: an audit row, a run row, or a log line naming the workflow. Read-only.
- **The video shows what the log says.** Open the stills in `<name>-frames/`, one every ten seconds, and look at them: captions readable, panels showing what they claim, no secret and no real personal data on screen. Then delete that directory. An audience sees everything in the video, so read every command's output in rehearsal before it goes on screen, and never run a command that prints configuration or credentials.
