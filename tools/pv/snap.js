// 確認用に、指定した時刻のコマだけ PNG で書き出す。 node snap.js <scene.html> <出力フォルダ> [--lang en] 1.5 5 9 ...
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const [scene, outDir, ...rest] = process.argv.slice(2);
const li = rest.indexOf('--lang');
const lang = li >= 0 ? rest.splice(li, 2)[1] : 'ja';
const times = rest;
(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
  page.on('pageerror', (e) => { console.error('page error:', e.message); process.exit(1); });
  await page.goto('file://' + path.resolve(scene) + '?lang=' + lang);
  await page.evaluate(() => window.setup());
  for (const t of times.map(Number)) {
    await page.evaluate((t) => window.seek(t), t);
    await page.screenshot({ path: path.join(outDir, `t${t.toFixed(2)}.png`) });
  }
  await browser.close();
})();
