// App Store のスクリーンショットを作る。UI テストで撮った画面に、見出しと説明をつける。
// node compose.js <撮った画面のフォルダ（xcresult の書き出し）> <出力フォルダ> <iphone|ipad> <ja|en>
// fonts/ に Shippori Mincho SemiBold、Zen Kaku Gothic New Medium、Cormorant Garamond を置いておく（Google Fonts）
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const [rawDir, outDir, device, lang] = process.argv.slice(2);
const copy = JSON.parse(fs.readFileSync(path.join(__dirname, 'copy.json'), 'utf8'))[lang];
const size = device === 'ipad' ? { w: 2064, h: 2752 } : { w: 1320, h: 2868 };

// xcresult の書き出しでは、ファイル名はばらばらなので manifest.json で名前を引く
const manifest = JSON.parse(fs.readFileSync(path.join(rawDir, 'manifest.json'), 'utf8'));
const files = {};
for (const test of manifest) {
  for (const a of test.attachments) {
    const key = a.suggestedHumanReadableName.split('_')[0];
    if (/^\d\d-/.test(key)) files[key] = path.join(rawDir, a.exportedFileName);
  }
}

(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: size.w, height: size.h } });
  await page.goto('file://' + path.join(__dirname, 'frame.html'));
  for (const [i, item] of copy.entries()) {
    const src = files[item.shot];
    if (!src) { console.error('missing', item.shot); continue; }
    const data = 'data:image/png;base64,' + fs.readFileSync(src).toString('base64');
    await page.evaluate((args) => window.setup(args), {
      ...size, lang, ipad: device === 'ipad', no: String(i + 1).padStart(2, '0'),
      title: item.title, sub: item.sub, src: data,
    });
    await page.waitForTimeout(200);
    const out = path.join(outDir, `${device}-${String(i + 1).padStart(2, '0')}.png`);
    await page.screenshot({ path: out });
    console.log(out);
  }
  await browser.close();
})();
