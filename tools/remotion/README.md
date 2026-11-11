# PV（Remotion 版）

`tools/pv` の素材（画面・写真・タイムラプス動画・フォント）をそのまま使って、Remotion で PV を作る。
ばねの動き、場面のつなぎ（スライド・フェード）、動画の再生、BGM の音量の出し入れを React で書く。

- `src/Intro.tsx` アプリ紹介（1.8 時点）。最初に「でできること」4つの目次 → 撮る・モザイク → 試験までの日数 → 勉強仲間 → Vlog・投稿 → 終わり
- `src/Intro19.tsx` アプリ紹介（1.9 時点）。目次 → 顔のモザイク → ポモドーロ（休憩で撮影も止まる・Siri）→ 1年の草 → 親や塾に共有 → 終わり。新しい画面は Remotion の中で描く
- `src/Intro20.tsx` アプリ紹介（2.0 時点）。アップデートの紹介ではなく、はじめて見る人向け（NEW の札なし）。目次 → 顔のモザイク → ポモドーロ → 編集と時刻の飾り → クエストとジェム → 1年の草 → 終わり。英語版は YouTube の英語のチャンネル用
- `src/copy.ts`・`src/copy19.ts`・`src/copy20.ts` 文言（日本語・英語）。宣伝文句らしくしない
- `src/ui.tsx` 共通の見た目（方眼紙・テープ・見出し・画面の枠・吹き出し）

```sh
cd tools/remotion
npm install
# 先に tools/pv で素材を作る：python3 timelapse.py（動画のコマとモザイク）、python3 thumbs.py（画面の中の写真）
# BGM は音量を下げたものを tools/pv/out/bgm-lofi.m4a に置く（-24 LUFS、高い音を少し削る）
ffmpeg -i ../../StudyTimerAndVideo/Resources/BGM/LofiStudy.m4a -t 40 -af "loudnorm=I=-24:TP=-3:LRA=11,treble=g=-5:f=4500,lowpass=f=9000" -ar 44100 -c:a aac -b:a 160k ../pv/out/bgm-lofi.m4a
npx remotion render src/index.ts Intro out/studyreel-intro-ja.mp4 --props '{"lang":"ja"}' --public-dir ../pv --crf 18
npx remotion render src/index.ts Intro out/studyreel-intro-en.mp4 --props '{"lang":"en"}' --public-dir ../pv --crf 18
npx remotion render src/index.ts Intro19 out/studyreel-1.9-ja.mp4 --props '{"lang":"ja"}' --public-dir ../pv --crf 18
npx remotion render src/index.ts Intro20 out/studyreel-intro-2.0-en.mp4 --props '{"lang":"en"}' --public-dir ../pv --crf 18
npm run studio   # ブラウザで見ながら直す
```

このクラウドの環境では、Remotion が取ってくる Chrome の代わりに `--browser-executable /opt/pw-browsers/chromium_headless_shell-1243/chrome-headless-shell-linux64/chrome-headless-shell`（版の数字は環境で変わる。`find /opt/pw-browsers -name 'chrome-headless-shell' -type f` で探す）。フォントは git に入っていないので、Google Fonts（github.com/google/fonts の ofl/shipporimincho・zenkakugothicnew・cormorantgaramond）から tools/pv/fonts/ に置く。`` を付ける。

Remotion は、個人と社員3人までの会社なら無料で使える（それより大きい会社は有料のライセンス）。
