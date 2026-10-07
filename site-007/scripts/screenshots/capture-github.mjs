// Captures GitHub UI evidence at a fixed 1440x900 viewport with a dedicated, persistent Edge profile.
// Usage: node capture-github.mjs <outDir>   (sign in to GitHub in the window that opens on first run)
// PW_ROOT points to a folder whose node_modules contains playwright-core.
import { createRequire } from 'node:module';
import path from 'node:path';
import os from 'node:os';

const require = createRequire(process.env.PW_ROOT ? path.join(process.env.PW_ROOT, 'x.js') : import.meta.url);
const { chromium } = require('playwright-core');

const outDir = process.argv[2];
if (!outDir) throw new Error('Pass the output image directory.');
const R = 'https://github.com/devopsabcs-engineering/APIM_apim-landing-zone-accelerator';
const shots = [
  ['lab-01/01-04-gh-infra-run.png', `${R}/actions/runs/37652742332`, 780],
  ['lab-02/02-05-gh-pr-checks.png', `${R}/pull/30`, 820],
  ['lab-03/03-05-gh-release-runs.png', `${R}/actions/workflows/release-apiops-007.yml`, 820],
  ['lab-03/03-06-gh-release-run.png', `${R}/actions/runs/37660072964`, 820],
  ['lab-03/03-07-gh-releases.png', `${R}/releases`, 820],
  ['lab-03/03-08-gh-rejected-run.png', `${R}/actions/runs/37658029033`, 780],
  ['lab-03/03-09-gh-prod-environment.png', `${R}/settings/environments`, 780],
  ['lab-05/05-04-gh-extract-run.png', `${R}/actions/runs/37665497460`, 780],
  ['lab-05/05-05-gh-projected-branch.png', `${R}/compare/main...apim007/extract-37665497460`, 900],
  ['lab-09/09-03-gh-ai-b-run.png', `${R}/actions/runs/37663312626`, 820],
  ['lab-10/10-02-gh-teardown-run.png', `${R}/actions/runs/37624727789`, 780],
];

const context = await chromium.launchPersistentContext(path.join(os.tmpdir(), 'apim007-gh-profile'), {
  channel: 'msedge', headless: false, viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1,
});
const page = context.pages()[0] ?? await context.newPage();
await page.goto('https://github.com/');
const deadline = Date.now() + 5 * 60 * 1000;
while (!(await page.locator('meta[name="user-login"][content]:not([content=""])').count())) {
  if (Date.now() > deadline) throw new Error('Not signed in to GitHub within 5 minutes.');
  if (!page.url().includes('/login') && !page.url().includes('/session')) await page.goto('https://github.com/login').catch(() => {});
  await page.waitForTimeout(5000);
  if (page.url() === 'https://github.com/' || page.url().startsWith('https://github.com/?')) await page.reload().catch(() => {});
}
console.log('Signed in.');
for (const [file, url, height] of shots) {
  await page.goto(url);
  await page.waitForLoadState('networkidle', { timeout: 20000 }).catch(() => {});
  await page.waitForTimeout(1500);
  await page.addStyleTag({ content: '.AppHeader-user, .AppHeader-actions, notification-indicator { visibility: hidden !important; }' });
  await page.screenshot({ path: path.join(outDir, file), fullPage: true, clip: { x: 0, y: 0, width: 1440, height } });
  console.log('captured', file);
}
await context.close();
