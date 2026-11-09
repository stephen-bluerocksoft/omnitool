// Records a walkthrough guide being driven in a real browser. Copied beside the driver in the project's
// gitignored temp/walkthrough/video/, because an import of playwright-core resolves from this file's directory.
import { chromium } from 'playwright-core';
import { spawn, spawnSync } from 'node:child_process';
import { appendFileSync, existsSync, mkdirSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';

const FPS = 10;
const SAMPLE_SECONDS = 10; // A still this often, under <out>-frames/, so the video can be checked before it is sent.
const LOOPBACK = new Set(['localhost', '127.0.0.1', '[::1]']);
const SHELL_TIMEOUT_MS = 240000;
const CONTEXT_GONE = /Execution context was destroyed|Target (page, context or browser )?(has been )?closed/;

const escapeHtml = (text) => text.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));

/** The ffmpeg Playwright installs beside its browser; a separate program, fed through a pipe. */
function findFfmpeg(browserPath) {
  const cache = browserPath.split(/[\\/]chromium-\d+[\\/]/)[0];
  const dirs = readdirSync(cache).filter((name) => /^ffmpeg-\d+$/.test(name)).sort().reverse();
  for (const dir of dirs) {
    const file = readdirSync(join(cache, dir)).find((name) => /^ffmpeg-(linux|mac)/.test(name));
    if (file) return join(cache, dir, file);
  }
  throw new Error('no ffmpeg found; run: npx playwright-core install --no-shell --no-remove chromium ffmpeg');
}

/** One recorded run of a guide: the browser, the video, and a log of every action and check. */
export class Take {
  /**
   * @param {object} options
   * @param {string} options.out path prefix for the outputs: .webm, .log and .results.json
   * @param {string} options.cwd directory that shell() commands run in
   */
  constructor({ out, cwd }) {
    this.out = out;
    this.cwd = cwd;
    this.paused = false;
    this.stopping = false;
    this.caption = '';
    this.step = '';
    this.results = [];
    this.frames = 0;
    this.seen = new Set();
  }

  /** Open the browser and start recording. Frames are written only while not paused, which is how waits are cut. */
  async start() {
    const browserPath = chromium.executablePath();
    if (!existsSync(browserPath)) {
      throw new Error('no browser found; run: npx playwright-core install --no-shell --no-remove chromium ffmpeg');
    }
    mkdirSync(`${this.out}-frames`, { recursive: true });
    this.browser = await chromium.launch({ executablePath: browserPath, headless: true });
    this.context = await this.browser.newContext({
      viewport: { width: 1440, height: 900 }, acceptDownloads: true, bypassCSP: true,
    });
    this.page = await this.context.newPage();
    this.page.setDefaultTimeout(20000);
    this.page.on('load', () => this.paint().catch((e) => this.#ignoreNavigation(e)));
    this.page.on('pageerror', (e) => this.#finding(`page error: ${e.message.split('\n')[0]}`));
    this.page.on('console', (m) => { if (m.type() === 'error') this.#finding(`console error: ${m.text().slice(0, 300)}`); });
    this.page.on('response', (r) => {
      if (r.status() >= 500) this.#finding(`${r.status()} ${r.request().method()} ${new URL(r.url()).pathname}`);
    });
    this.encoder = spawn(findFfmpeg(browserPath), ['-y', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg',
      '-i', 'pipe:0', '-an', '-c:v', 'libvpx-vp9', '-pix_fmt', 'yuv420p', '-deadline', 'realtime', '-cpu-used', '8',
      '-crf', '32', '-b:v', '0', '-threads', '4', `${this.out}.webm`], { stdio: ['pipe', 'ignore', 'ignore'] });
    this.encoder.stdin.on('error', (e) => { this.encoderError = e; });
    const cdp = await this.context.newCDPSession(this.page);
    cdp.on('Page.screencastFrame', (f) => {
      this.frame = Buffer.from(f.data, 'base64');
      cdp.send('Page.screencastFrameAck', { sessionId: f.sessionId }).catch((e) => this.#ignoreNavigation(e));
    });
    await cdp.send('Page.startScreencast', { format: 'jpeg', quality: 80, maxWidth: 1440, maxHeight: 900 });
    this.timer = setInterval(() => {
      if (this.paused || !this.frame || this.encoderError) return;
      this.encoder.stdin.write(this.frame);
      if (this.frames % (FPS * SAMPLE_SECONDS) === 0) {
        writeFileSync(`${this.out}-frames/${String(this.frames / FPS).padStart(5, '0')}s.jpg`, this.frame);
      }
      this.frames += 1;
    }, 1000 / FPS);
  }

  /** Finish the video and write the results file. Throws if the encoder failed, since the video is then unusable. */
  async stop() {
    this.stopping = true;
    clearInterval(this.timer);
    const code = await new Promise((resolve) => { this.encoder.on('close', resolve); this.encoder.stdin.end(); });
    await this.browser.close();
    writeFileSync(`${this.out}.results.json`, JSON.stringify(this.results, null, 1));
    if (code !== 0 || this.encoderError) throw new Error(`the video encoder failed with exit code ${code}`);
    return { seconds: Math.round(this.frames / FPS), bytes: statSync(`${this.out}.webm`).size };
  }

  /** Something went wrong behind the screen. It does not stop the take, and each one is logged once to be looked at. */
  #finding(text) {
    if (this.seen.has(text)) return;
    this.seen.add(text);
    this.log('finding', this.step, text);
  }

  #ignoreNavigation(error) {
    if (this.stopping || CONTEXT_GONE.test(error.message)) return;
    this.log('warning', this.step, error.message.split('\n')[0], false);
  }

  /** Add one row to the log and the results file. */
  log(kind, step, text, ok = true) {
    this.results.push({ at: new Date().toISOString(), kind, step, text, ok });
    const mark = !ok ? 'FAIL' : kind === 'finding' ? 'LOOK' : 'ok  ';
    const line = `${mark} ${kind.padEnd(7)} ${step} ${text}`;
    console.log(line);
    appendFileSync(`${this.out}.log`, `${line}\n`);
  }

  /** Let the viewer read the screen. */
  async hold(ms = 900) { await this.page.waitForTimeout(ms); }

  /** Open a page on this machine. Refuses any other host, so a take can never touch a shared system. */
  async goto(url) {
    const { protocol, hostname } = new URL(url);
    if (!['http:', 'https:'].includes(protocol) || !LOOPBACK.has(hostname)) {
      throw new Error(`refusing ${url}: a take only opens pages on this machine`);
    }
    await this.page.goto(url);
  }

  /** Draw the caption bar over whatever page is open. */
  async paint() {
    await this.page.evaluate((text) => {
      let el = document.getElementById('take-caption');
      if (!el) {
        el = document.createElement('div');
        el.id = 'take-caption';
        el.style.cssText = 'position:fixed;left:0;right:0;bottom:0;z-index:2147483647;padding:12px 24px;'
          + 'background:rgba(15,23,42,.93);color:#fff;font:600 19px/1.35 system-ui,sans-serif;pointer-events:none;';
        document.documentElement.appendChild(el);
      }
      el.textContent = text;
      el.style.display = text ? 'block' : 'none';
    }, this.caption);
  }

  /** Start a guide step: the caption opens with its number, as in "2.1 Request the records". */
  async cap(text, ms = 1500) {
    this.step = text.split(' ')[0];
    this.caption = text;
    this.log('step', this.step, text);
    await this.paint();
    await this.hold(ms);
  }

  /** Draw a red ring around an element, so a viewer sees what is about to be used or checked. */
  async ring(locator) {
    await locator.scrollIntoViewIfNeeded();
    await this.clearCaption(locator);
    await locator.evaluate((e) => {
      e.style.outline = '3px solid #ef4444';
      e.style.outlineOffset = '2px';
      setTimeout(() => { e.style.outline = ''; }, 1400);
    });
    await this.hold(600);
  }

  /**
   * Keep the caption bar off an element. "Into view if needed" counts an element under the fixed bar as
   * visible, so centre it when the bar covers it, and move the bar to the top when it still does (a dialog
   * with nothing to scroll). The bar returns to the bottom for the next element.
   */
  async clearCaption(locator) {
    const place = (top) => this.page.evaluate((atTop) => {
      const bar = document.getElementById('take-caption');
      if (bar) { bar.style.top = atTop ? '0' : ''; bar.style.bottom = atTop ? 'auto' : '0'; }
    }, top);
    const covered = () => locator.evaluate((e) => {
      const bar = document.getElementById('take-caption');
      if (!bar || bar.style.display === 'none') return false;
      const r = e.getBoundingClientRect();
      const c = bar.getBoundingClientRect();
      return r.bottom > c.top && r.top < c.bottom;
    });
    await place(false);
    if (await covered()) await locator.evaluate((e) => e.scrollIntoView({ block: 'center' }));
    if (await covered()) await place(true);
  }

  /** Press a button by name. The last match wins, which is a dialog's confirm when a name repeats. */
  async press(name, { within, first = false } = {}) {
    const all = (within ?? this.page).getByRole('button', { name, exact: typeof name === 'string' });
    const button = first ? all.first() : all.last();
    await button.waitFor({ state: 'visible' });
    await this.ring(button);
    await button.click();
    this.log('press', this.step, String(name));
    await this.hold(800);
  }

  /** Type into a field, one key at a time, so a viewer sees it happen. */
  async type(label, value) {
    const box = this.page.getByLabel(label, { exact: false }).last();
    await box.waitFor({ state: 'visible' });
    await this.ring(box);
    await box.click();
    await box.fill('');
    await box.pressSequentially(value, { delay: 25 });
    this.log('type', this.step, `${label}: ${value}`);
    await this.hold(400);
  }

  /** Choose from a native select or a listbox. */
  async choose(label, option) {
    const box = this.page.getByLabel(label, { exact: false }).last();
    await box.waitFor({ state: 'visible' });
    await this.ring(box);
    if (await box.evaluate((e) => e.tagName) === 'SELECT') {
      const match = box.locator('option', { hasText: option }).first();
      const value = await match.getAttribute('value');
      await box.selectOption(value ?? { label: (await match.textContent()).trim() });
    } else {
      await box.click();
      await this.page.getByRole('option', { name: option }).first().click();
    }
    this.log('choose', this.step, `${label}: ${option}`);
    await this.hold(600);
  }

  /** An Expect that is text on screen: visible text only, ringed and logged. Throws when it does not appear. */
  async see(text, { within, timeout = 20000 } = {}) {
    const match = (within ?? this.page).getByText(text, { exact: false }).locator('visible=true').first();
    await this.#checked(String(text), async () => {
      await match.waitFor({ state: 'visible', timeout });
      await this.ring(match);
    });
    await this.hold(500);
  }

  /** An Expect that is not text on screen, such as a field's value or a file's contents. Throws when false. */
  check(text, ok) {
    this.log('expect', this.step, text, ok);
    if (!ok) throw new Error(`expected: ${text}`);
  }

  async #checked(text, action) {
    try {
      await action();
    } catch (error) {
      this.log('expect', this.step, text, false);
      throw error;
    }
    this.log('expect', this.step, text);
  }

  /** Whether text is visible now; for polling, never as an Expect. */
  async has(text, within) {
    return (within ?? this.page).getByText(text, { exact: false }).locator('visible=true').first().isVisible();
  }

  /**
   * Off camera: repeat check() until it is true, then say on screen how long it took, so no cut is silent.
   * reopen() puts the page back where check() can read it. A wait that runs out fails the take.
   */
  async waitOff(what, check, { reopen, minutes = 12, every = 15000 }) {
    const started = Date.now();
    this.paused = true;
    try {
      while (Date.now() - started < minutes * 60000) {
        if (await check()) {
          const secs = Math.round((Date.now() - started) / 1000);
          this.log('wait', this.step, `${what}: ${secs}s`);
          this.paused = false;
          const before = this.caption;
          this.caption = `${before}  [waited ${Math.floor(secs / 60)}m ${secs % 60}s; cut from the video]`;
          await this.paint();
          await this.hold(1500);
          this.caption = before;
          await this.paint();
          return;
        }
        await this.page.waitForTimeout(every);
        await reopen();
      }
      this.log('wait', this.step, `${what}: gave up after ${minutes} min`, false);
      throw new Error(`timed out waiting for ${what}`);
    } finally {
      this.paused = false;
    }
  }

  async #overlay(html, ms) {
    await this.page.evaluate((content) => {
      const el = document.createElement('div');
      el.id = 'take-panel';
      el.style.cssText = 'position:fixed;inset:0 0 56px 0;z-index:2147483646;background:#0b1020;color:#e2e8f0;'
        + 'padding:24px;overflow:auto;font:15px/1.45 ui-monospace,Menlo,monospace;white-space:pre-wrap;';
      el.innerHTML = content;
      document.documentElement.appendChild(el);
    }, html);
    await this.hold(ms);
    await this.page.evaluate(() => document.getElementById('take-panel')?.remove());
  }

  /** Show real text full screen, such as a downloaded CSV. The text is escaped. */
  async panel(text, ms = 4500) { await this.#overlay(escapeHtml(text), ms); }

  /** Show an image full screen, such as a rendered page of a downloaded PDF. */
  async image(pngBase64, ms = 5000) {
    await this.#overlay(`<img style="height:100%;display:block;margin:auto" src="data:image/png;base64,${pngBase64}">`, ms);
  }

  /**
   * Run a command, show its real output on screen, and return that output. The recording stops while it runs,
   * so a slow command is cut. hide removes lines of known noise from the screen, never from the returned text.
   */
  async shell(cmd, args, { ms = 5000, hide } = {}) {
    const res = spawnSync(cmd, args, { cwd: this.cwd, encoding: 'utf8', timeout: SHELL_TIMEOUT_MS, maxBuffer: 1 << 26 });
    if (res.error) throw res.error;
    if (res.status !== 0) throw new Error(`${cmd} ${args[0]} exited ${res.status}: ${res.stderr.slice(-400)}`);
    const output = res.stdout + res.stderr;
    const shown = hide ? output.split('\n').filter((line) => !hide.test(line)).join('\n') : output;
    const command = `${cmd} ${args.join(' ')}`;
    this.log('shell', this.step, command);
    await this.#overlay(`<b style="color:#86efac">$ ${escapeHtml(command)}</b>\n\n${escapeHtml(shown)}`, ms);
    return output;
  }

  /** Run trigger(), save the file it downloads beside the outputs, and return the saved path and name. */
  async download(trigger, tag) {
    const [file] = await Promise.all([this.page.waitForEvent('download', { timeout: 30000 }), trigger()]);
    const name = basename(file.suggestedFilename());
    const path = `${this.out}-${tag}-${name}`;
    await file.saveAs(path);
    this.log('file', this.step, name);
    return { path, name };
  }
}

/**
 * The driver's entry point: run the moments in order and finish the video, even after a failure.
 * moments is a list of [key, async function] pairs; only limits a rehearsal to some keys. Returns the exit code.
 */
export async function runTake(take, moments, only) {
  await take.start();
  let failed = false;
  try {
    for (const [key, moment] of moments) {
      if (!only || only.includes(key)) await moment();
    }
  } catch (error) { // Top-level entry point: any failure is logged and fails the take.
    failed = true;
    take.log('error', take.step, error.message.split('\n')[0], false);
    await take.page.screenshot({ path: `${take.out}-fail.png` });
    console.log(`--- what was on screen\n${(await take.page.locator('body').ariaSnapshot()).slice(0, 5000)}`);
  }
  const video = await take.stop();
  const bad = take.results.filter((row) => !row.ok);
  const findings = take.results.filter((row) => row.kind === 'finding');
  console.log(`\nrows ${take.results.length}, failures ${bad.length}, findings ${findings.length}, video ${video.seconds}s, ${video.bytes} bytes`);
  for (const row of findings) console.log('LOOK', row.step, row.text);
  for (const row of bad) console.log('FAIL', row.step, row.text);
  return failed || bad.length ? 1 : 0;
}
