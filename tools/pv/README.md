# PV（宣伝動画）

アプリの共有カードと同じ雰囲気（方眼紙・マスキングテープ・ポラロイド）で、縦型 1080×1920・30fps の動画を作る。
場面は HTML で書き、`window.seek(秒)` でその時刻の見た目にして、1コマずつ Chromium で撮って ffmpeg に渡す。

- `v15.html` 1.5 の PV（録画・モザイク・ギャラリー・共有・Vlog）
- `next.html` 次のアップデートの PV（目標と D-day・過去問・共有カード・テーマカラー）
- `pv.css` / `pv.js` 共通の見た目と、時刻から値を出す道具
- `assets/` 画面（store-shots / layout-check の成果物）と写真
- `fonts/` Shippori Mincho・Zen Kaku Gothic New・Cormorant Garamond（tools/appstore/frames/fonts と同じ。git には入れない）

```sh
cd tools/pv
node render.js v15.html out/studyreel-1.5-ja.mp4 --bgm ../../StudyTimerAndVideo/Resources/BGM/Piano.m4a
node render.js next.html out/studyreel-next-ja.mp4 --bgm ../../StudyTimerAndVideo/Resources/BGM/LofiStudy.m4a
node snap.js v15.html out/check 1.5 5 9      # 確認用に、その時刻のコマだけ PNG にする
```

App Store のプレビュー（6.9 インチは 886×1920）にするときは、できた動画を ffmpeg で縮める:
`ffmpeg -i out/studyreel-1.5-ja.mp4 -vf scale=886:1920 -c:a copy out/ja-iphone67.mp4`
