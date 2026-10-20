// PV（宣伝動画）を書き出す。scene の HTML を Chromium で開き、window.seek(秒) で1コマずつ進めて ffmpeg に流す。
// node render.js <scene.html> <出力.mp4> [--bgm 曲.m4a] [--fps 30] [--size 1080x1920] [--start 秒] [--end 秒]
// scene は window.setup() で長さ（秒）を返し、window.seek(t) でその時刻の見た目にする
const { chromium } = require('playwright');
const { spawn } = require('child_process');
const path = require('path');

const args = process.argv.slice(2);
const scene = args[0];
const out = args[1];
const opt = (name, fallback) => {
  const i = args.indexOf('--' + name);
  return i >= 0 ? args[i + 1] : fallback;
};
const fps = Number(opt('fps', 30));
const [w, h] = opt('size', '1080x1920').split('x').map(Number);
const bgm = opt('bgm', null);
const start = Number(opt('start', 0));

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
  page.on('pageerror', (e) => { console.error('page error:', e.message); process.exit(1); });
  await page.goto('file://' + path.resolve(scene));
  const duration = await page.evaluate(() => window.setup());
  const end = Number(opt('end', duration));
  const frames = Math.round((end - start) * fps);
  console.log(`${scene}: ${duration}s, ${frames} frames at ${fps}fps`);

  const ff = ['-y', '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'png', '-i', '-'];
  if (bgm) ff.push('-i', bgm);
  ff.push('-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '18', '-preset', 'medium', '-movflags', '+faststart');
  if (bgm) {
    // 曲は動画の長さで切って、最後の1.5秒で消す
    ff.push('-af', `afade=t=in:d=0.5,afade=t=out:st=${end - start - 1.5}:d=1.5`, '-c:a', 'aac', '-b:a', '160k', '-shortest');
  }
  ff.push(out);
  const enc = spawn('ffmpeg', ff, { stdio: ['pipe', 'inherit', 'inherit'] });
  const done = new Promise((resolve, reject) => enc.on('close', (code) => (code === 0 ? resolve() : reject(new Error('ffmpeg ' + code)))));

  for (let i = 0; i < frames; i++) {
    const t = start + i / fps;
    await page.evaluate((t) => window.seek(t), t);
    const png = await page.screenshot({ type: 'png' });
    if (!enc.stdin.write(png)) await new Promise((r) => enc.stdin.once('drain', r));
    if (i % 60 === 0) process.stdout.write(`\r${i}/${frames}`);
  }
  enc.stdin.end();
  await done;
  console.log(`\nwrote ${out}`);
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
