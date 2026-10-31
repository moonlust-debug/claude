#!/usr/bin/env node
// Render an HTML animation to MP4, one frame at a time.
//
// Screen-recording a page in real time drops frames whenever the machine is
// busy, so instead the page is frozen and stepped: for every frame we set the
// time to exactly i / fps, take a screenshot, and pipe the PNG to ffmpeg.
// The result is identical no matter how slow the render is.
//
// Usage:
//   node render.mjs <page.html> <out.mp4> [--fps 30] [--duration 10]
//                   [--width 1920] [--height 1080] [--audio track.mp3]
//
// The page decides how time is applied:
//   1. window.renderFrame(t)  (seconds), if the page defines it. Preferred.
//   2. Otherwise GSAP's globalTimeline and every CSS/Web Animation are paused
//      and seeked to t.
// The page may set window.DURATION (seconds) to override --duration.
import { createRequire } from 'node:module';
import { spawn } from 'node:child_process';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { existsSync } from 'node:fs';

const args = process.argv.slice(2);
const flag = (name, dflt) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : dflt;
};
const positional = args.filter((a, i) => !a.startsWith('--') && !(i > 0 && args[i - 1].startsWith('--')));
const [input, output] = positional;
if (!input || !output) {
  console.error('usage: node render.mjs <page.html> <out.mp4> [--fps 30] [--duration 10] [--width 1920] [--height 1080] [--audio file]');
  process.exit(2);
}

const fps = Number(flag('fps', 30));
const width = Number(flag('width', 1920));
const height = Number(flag('height', 1080));
const audio = flag('audio', null);

// Playwright is resolved from wherever it is installed globally, not from this
// script's folder: the skill ships no node_modules of its own.
const require = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = require('playwright'));
} catch {
  const { execSync } = await import('node:child_process');
  const root = execSync('npm root -g', { encoding: 'utf8' }).trim();
  ({ chromium } = createRequire(resolve(root, 'noop.js'))('playwright'));
}

const url = /^https?:/.test(input) ? input : pathToFileURL(resolve(input)).href;
if (!/^https?:/.test(input) && !existsSync(resolve(input))) {
  console.error(`not found: ${input}`);
  process.exit(2);
}

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
page.on('pageerror', (e) => console.error('page error:', e.message));
await page.goto(url, { waitUntil: 'networkidle' });
await page.evaluate(() => document.fonts && document.fonts.ready);
// Pages that load assets asynchronously can set window.READY = false and flip
// it to true when done.
await page.waitForFunction(() => window.READY !== false, null, { timeout: 60000 });

const duration = Number(await page.evaluate(() => window.DURATION)) || Number(flag('duration', 10));
const frames = Math.round(duration * fps);

const mode = await page.evaluate(() => {
  if (typeof window.renderFrame === 'function') return 'renderFrame';
  if (window.gsap) window.gsap.globalTimeline.pause();
  for (const a of document.getAnimations()) a.pause();
  return window.gsap ? 'gsap+waapi' : 'waapi';
});

const ffArgs = ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(fps), '-i', '-'];
if (audio) ffArgs.push('-i', audio, '-c:a', 'aac', '-b:a', '192k', '-shortest');
ffArgs.push('-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'medium', '-crf', '18', '-movflags', '+faststart', output);
const ff = spawn('ffmpeg', ffArgs, { stdio: ['pipe', 'inherit', 'inherit'] });
const ffDone = new Promise((ok, fail) => ff.on('close', (c) => (c === 0 ? ok() : fail(new Error(`ffmpeg exited ${c}`)))));

console.log(`rendering ${frames} frames (${duration}s @ ${fps}fps, ${width}x${height}, mode: ${mode})`);
for (let i = 0; i < frames; i++) {
  const t = i / fps;
  await page.evaluate(async (t) => {
    if (typeof window.renderFrame === 'function') {
      await window.renderFrame(t);
    } else {
      if (window.gsap) window.gsap.globalTimeline.seek(t, false);
      for (const a of document.getAnimations()) a.currentTime = t * 1000;
    }
  }, t);
  const png = await page.screenshot({ type: 'png' });
  if (!ff.stdin.write(png)) await new Promise((r) => ff.stdin.once('drain', r));
  if (i % fps === 0) process.stdout.write(`\r${Math.round((i / frames) * 100)}%`);
}
ff.stdin.end();
await ffDone;
await browser.close();
console.log(`\rdone: ${output}`);
