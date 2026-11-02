# ASO（App Store の検索と見せ方）

文言の正本は `appstore/release.yml` の `localizations`。マージすると App Store Connect に反映される（1.8 から）。
今のストアの文言は、PR の App Store チェック（dry run）のログの「いまのストアの文言」で見られる。

## 1.7 時点（2026-10-24 に読み出し）

| 項目 | ja | en-US |
| --- | --- | --- |
| 名前 | StudyReel | StudyReel |
| サブタイトル | タイムラプスで残す、集中と学習の記録 | なし |
| キーワード | 勉強,タイマー,タイムラプス,学習,記録,集中,ポモドーロ,受験,資格,StudyReel,スタディリール,カメラ,動画,ストップウォッチ | study,timer,timelapse,focus,pomodoro,study tracker,productivity,stopwatch,exam,learning |
| プロモーションテキスト | なし | なし |
| 説明文 | 初期の内容（目標・教材・勉強仲間・Vlog がない） | 2文だけ |
| カテゴリ | 教育 | |

## 1.8 で変えること

| 項目 | ja | en-US |
| --- | --- | --- |
| 名前 | StudyReel - 勉強タイムラプス記録（22字） | StudyReel - Study Timelapse（27字） |
| サブタイトル | 受験生のためのVlog・集中タイマーと過去問管理（24字） | Focus timer & study vlog（24字） |
| キーワード | 勉強垢,自習,習慣,継続,教材,成績,グラフ,モザイク,モチベ,努力,資格,仲間（98バイト） | pomodoro,tracker,habit,exam,buddies,group,productivity,stopwatch,motivation,student,homework,log（96バイト） |

- 名前・サブタイトル・キーワードに同じ言葉を入れない（組み合わせで「勉強＋仲間」「勉強＋習慣」などに当たる）
- 前のキーワードにあった「StudyReel」は名前と重複、「タイムラプス・記録・集中・タイマー・受験」は名前とサブタイトルに移した
- 説明文は検索の対象ではないので、冒頭3行で何のアプリか伝える。勉強仲間、目標、教材、Vlog を足した
- プロモーションテキストは審査なしで変えられる。受験の時期に合わせて差し替える

## まだやること

- スクリーンショットの1枚目を「タイムラプスで撮る」画面にして、見出しに「タイムラプス」を入れる（`tools/appstore/frames/copy.json`）。勉強仲間の画面も1枚入れる
- 変更から4週間、App Store Connect の App Analytics で、表示回数・ページ表示・転換率・流入元を前と比べる（1.8 は 2026-10-24 公開。11-21 ごろに見る）
- 週のダウンロードが 30 件を超えたら、スクリーンショット1枚目の A/B テスト（Product Page Optimization）
