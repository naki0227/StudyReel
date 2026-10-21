# PV（宣伝動画）

アプリの共有カードと同じ雰囲気（方眼紙・マスキングテープ・ポラロイド）で、縦型 1080×1920・30fps の動画を作る。
場面は HTML で書き、`window.seek(秒)` でその時刻の見た目にして、1コマずつ Chromium で撮って ffmpeg に渡す。

- `v15.html` 1.5 の PV（録画・モザイク・ギャラリー・共有・Vlog）
- `next.html` 次のアップデートの PV（目標と D-day・過去問・共有カード・テーマカラー）
- `v17.html` 1.7 の PV（満点が最初から入る・ホームの最高点に反映・レビュー）。画面は StoreScreenshotTests の test9
- `pv.css` / `pv.js` 共通の見た目と、時刻から値を出す道具
- `assets/` 画面（store-shots / layout-check の成果物）と写真。英語の画面は `assets/en/`（`--lang en` で使う）
- `fonts/` Shippori Mincho・Zen Kaku Gothic New・Cormorant Garamond（tools/appstore/frames/fonts と同じ。git には入れない）

```sh
cd tools/pv
node render.js v15.html out/studyreel-1.5-ja.mp4 --bgm ../../StudyTimerAndVideo/Resources/BGM/Piano.m4a
node render.js next.html out/studyreel-next-ja.mp4 --bgm ../../StudyTimerAndVideo/Resources/BGM/LofiStudy.m4a
node snap.js v15.html out/check 1.5 5 9      # 確認用に、その時刻のコマだけ PNG にする
```

App Store のプレビュー動画は、字幕や写真を入れられない（画面の録画そのもの）ので、この PV とは別に作る。
`.github/workflows/preview.yml` でシミュレータを録画し、`tools/appstore/preview.py` で切り出す（計画は `tools/appstore/previews/*.json`）。
