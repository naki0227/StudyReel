// 確認用に、指定した時刻のコマだけ PNG で書き出す。 node snap.js <scene.html> <出力フォルダ> 1.5 5 9 ...
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const [scene, outDir, ...times] = process.argv.slice(2);
(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
  page.on('pageerror', (e) => { console.error('page error:', e.message); process.exit(1); });
  await page.goto('file://' + path.resolve(scene));
  await page.evaluate(() => window.setup());
  for (const t of times.map(Number)) {
    await page.evaluate((t) => window.seek(t), t);
    await page.screenshot({ path: path.join(outDir, `t${t.toFixed(2)}.png`) });
  }
  await browser.close();
})();
