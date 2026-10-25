# PV（Remotion 版）

`tools/pv` の素材（画面・写真・タイムラプス動画・フォント）をそのまま使って、Remotion で PV を作る。
ばねの動き、場面のつなぎ（スライド・フェード）、動画の再生、BGM の音量の出し入れを React で書く。

- `src/Intro.tsx` アプリ紹介（1.8 時点）。最初に「でできること」4つの目次 → 撮る・モザイク → 試験までの日数 → 勉強仲間 → Vlog・投稿 → 終わり
- `src/copy.ts` 文言（日本語・英語）。宣伝文句らしくしない
- `src/ui.tsx` 共通の見た目（方眼紙・テープ・見出し・画面の枠・吹き出し）

```sh
cd tools/remotion
npm install
# 先に tools/pv で素材を作る：python3 timelapse.py（動画のコマとモザイク）、python3 thumbs.py（画面の中の写真）
# BGM は音量を下げたものを tools/pv/out/bgm-lofi.m4a に置く（-24 LUFS、高い音を少し削る）
ffmpeg -i ../../StudyTimerAndVideo/Resources/BGM/LofiStudy.m4a -t 40 -af "loudnorm=I=-24:TP=-3:LRA=11,treble=g=-5:f=4500,lowpass=f=9000" -ar 44100 -c:a aac -b:a 160k ../pv/out/bgm-lofi.m4a
npx remotion render src/index.ts Intro out/studyreel-intro-ja.mp4 --props '{"lang":"ja"}' --public-dir ../pv --crf 18
npx remotion render src/index.ts Intro out/studyreel-intro-en.mp4 --props '{"lang":"en"}' --public-dir ../pv --crf 18
npm run studio   # ブラウザで見ながら直す
```

このクラウドの環境では、Remotion が取ってくる Chrome の代わりに `--browser-executable /opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell` を付ける。

Remotion は、個人と社員3人までの会社なら無料で使える（それより大きい会社は有料のライセンス）。
