// Smoke test for the web app (docs/) in headless Chromium at phone size.
// Usage: node scripts/web-smoke.mjs   (needs the `playwright` package; CI installs it
// on the fly so the web app itself keeps zero dependencies)
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

// require() honours NODE_PATH, so a globally installed playwright works too.
const { chromium } = createRequire(import.meta.url)('playwright');

const root = join(fileURLToPath(new URL('.', import.meta.url)), '..', 'docs');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css',
  '.json': 'application/json', '.png': 'image/png', '.svg': 'image/svg+xml' };

const server = createServer(async (req, res) => {
  const path = normalize(decodeURIComponent(new URL(req.url, 'http://x').pathname));
  try {
    const body = await readFile(join(root, path === '/' ? 'index.html' : path));
    res.writeHead(200, { 'content-type': types[extname(path)] || 'application/octet-stream' });
    res.end(body);
  } catch {
    res.writeHead(404).end();
  }
}).listen(0);
const base = `http://localhost:${server.address().port}`;

const failures = [];
const check = (ok, message) => { if (!ok) failures.push(message); console.log(`${ok ? 'ok  ' : 'FAIL'} ${message}`); };

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
const errors = [];
page.on('pageerror', e => errors.push(e.message));
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

try {
  // Skip the one-time gesture hints overlay; it covers the score buttons.
  await page.addInitScript(() => localStorage.setItem('scorekeeper-hints-shown', '1'));
  // Stand in for Safari's audio session and count the tones the app starts.
  await page.addInitScript(() => {
    Object.defineProperty(navigator, 'audioSession', { value: { type: 'auto' } });
    window.__tones = 0;
    const create = AudioContext.prototype.createOscillator;
    AudioContext.prototype.createOscillator = function () { window.__tones++; return create.call(this); };
  });
  await page.goto(`${base}/index.html`);

  // Type the name immediately: the modal used to clear the field 100ms after opening.
  for (const name of ['MAYA', 'LEO']) {
    await page.click('#btn-add-player');
    await page.fill('#edit-name', name);
    await page.waitForTimeout(250); // let the modal's focus timer run after typing
    await page.click('#btn-confirm-edit');
  }
  const names = await page.locator('.player-row .player-name').allTextContents();
  check(names.join(',').includes('MAYA') && names.join(',').includes('LEO'), `players named as typed (${names})`);

  const plus = page.locator('.player-row').first().locator('button:has-text("+")').first();
  await plus.click();
  await page.waitForTimeout(200);
  check(await page.evaluate(() => window.__tones) > 0, 'the first tap plays a sound');
  check(await page.evaluate(() => navigator.audioSession.type) === 'playback',
    'sound ignores the iPhone silent switch (audioSession playback)');
  await plus.click();
  const firstScore = await page.locator('.player-row').first().locator('.player-score, .score').first().textContent();
  check(firstScore?.includes('2'), `two taps add 2 (${firstScore?.trim()})`);

  await page.click('#btn-undo');
  const afterUndo = await page.locator('.player-row').first().locator('.player-score, .score').first().textContent();
  check(afterUndo?.trim().startsWith('0'), `one undo reverts the burst (${afterUndo?.trim()})`);

  await plus.click();
  await page.click('#btn-end-game');
  await page.waitForSelector('.celebration-overlay');
  const winner = await page.textContent('.celebration-winner-name');
  check(winner === 'MAYA', `end game crowns the leader (${winner})`);
  await page.click('.btn-undo-end');

  // An "Undo" toast must close once another step is recorded, or its button
  // would undo that newer step instead of the one it was shown for.
  await page.click('#btn-reset');
  check(await page.locator('.toast-undo-btn').count() === 1, 'reset shows an Undo toast');
  await plus.click();
  await page.waitForTimeout(300);
  check(await page.locator('.toast-undo-btn').count() === 0, 'a new score change closes the Undo toast');

  await page.reload();
  const reloaded = await page.locator('.player-row').count();
  check(reloaded === 2, `players survive a reload (${reloaded})`);

  for (const path of ['/index.html', '/privacy.html', '/support.html']) {
    await page.goto(base + path);
    const width = await page.evaluate(() => document.documentElement.scrollWidth);
    check(width <= 390, `${path} has no horizontal scroll (${width}px)`);
  }

  check(errors.length === 0, `no console errors ${errors.length ? JSON.stringify(errors) : ''}`);
} finally {
  await browser.close();
  server.close();
}

if (failures.length) {
  console.error(`\n${failures.length} check(s) failed`);
  process.exit(1);
}
