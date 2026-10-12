# App Store Connect: StudyReel Pro

StudyReel Pro は 3 つの商品で構成します。月額・年額は自動更新サブスクリプション、買い切りは非消耗型です。
アプリは `Transaction.currentEntitlements` でどれか 1 つでも有効なら Pro として扱います。

| 種類 | Product ID | 価格 | お試し |
| --- | --- | --- | --- |
| 自動更新（1か月） | `com.ni.StudyReel.pro.monthly` | ¥300 | 1週間無料 |
| 自動更新（1年） | `com.ni.StudyReel.pro.yearly` | ¥2,000 | 1週間無料 |
| 非消耗型 | `com.ni.StudyReel.pro.lifetime` | ¥3,000 | なし |

## Subscription Group

- Reference Name: `StudyReel Pro`
- Group Display Name: `StudyReel Pro`
- 年額を月額より上のレベルに置く（月額 → 年額のアップグレード扱いにするため）

## Introductory Offer（月額・年額）

- Type: `Free`
- Duration: `1 Week`
- 対象: 新規ユーザー
- アプリは `isEligibleForIntroOffer` を確認して、対象者にだけ「最初の1週間は無料」「無料で試す」を表示します。

## Product 1: Monthly

- Reference Name: `StudyReel Pro Monthly`
- Display Name: EN `StudyReel Pro Monthly` / JA `StudyReel Pro 月額`
- Description:
  - EN: `No watermark, video fonts, and full-length recording.`
  - JA: `透かしなしの動画、フォント選び、全部録画が使えます。`

## Product 2: Yearly

- Reference Name: `StudyReel Pro Yearly`
- Display Name: EN `StudyReel Pro Yearly` / JA `StudyReel Pro 年額`
- Description:
  - EN: `A full year of StudyReel Pro.`
  - JA: `StudyReel Pro を1年間使えます。`

## Product 3: Lifetime（非消耗型）

- In-App Purchases → `+` → `Non-Consumable`
- Reference Name: `StudyReel Pro Lifetime`
- Display Name: EN `StudyReel Pro Lifetime` / JA `StudyReel Pro 買い切り`
- Description:
  - EN: `A one-time purchase. Use StudyReel Pro forever.`
  - JA: `一度の購入で StudyReel Pro をずっと使えます。`
- Family Sharing: 任意（オンにすると家族も使える）

## What Pro Includes

- 透かし（右下の「StudyReel」）なしで動画を保存
- 動画に入れる文字のフォントを選ぶ
- 全部録画（タイムラプスではなく等速で全部記録）
- 顔をスタンプで隠す
- 教科別の先週比・集中しやすい時間帯

## What Stays Free

- タイマー・ストップウォッチ
- 時刻入りのタイムラプス（透かしあり）
- 顔に自動でモザイク（録画後に位置を調整できる）
- 統計・カレンダー・推移グラフ
- ウィジェット

## Review Notes

- EN:
  `StudyReel Pro removes the watermark from exported videos, unlocks additional overlay fonts and full-length (real-time) recording, and adds face stickers and per-subject insights. Face mosaic (on-device Vision, nothing stored or sent), timer, time-lapse recording, stats, calendar, and trend charts remain free. Pro is available as monthly or yearly auto-renewable subscriptions (each with a 1-week free trial) or as a one-time lifetime purchase. Restore Purchases is on the paywall.`
- JA:
  `StudyReel Pro では、動画の透かしを外して保存できるほか、文字のフォント選択、全部録画（等速）、顔のスタンプ、教科別の分析が使えます。顔のモザイク（端末内のVisionで検出し、保存・送信なし）、タイマー、タイムラプス、統計、カレンダー、推移グラフは無料です。月額・年額の自動更新サブスクリプション（各1週間の無料体験つき）と、買い切りから選べます。購入の復元は課金画面にあります。`

## Checklist

1. `Agreements, Tax, and Banking` が完了しているか確認する。
2. サブスクリプショングループ `StudyReel Pro` に月額・年額を用意する（既存の商品は説明文を更新）。
3. 月額・年額に 1 週間の無料お試し（Introductory Offer）を設定する。
4. 非消耗型 `com.ni.StudyReel.pro.lifetime` を追加する。
5. 日本語・英語のローカライズを入れる。
6. 3 つとも `Ready to Submit` にして、アプリのバージョンに紐づけて審査に出す。
7. 審査用のスクリーンショット（課金画面）を最新の画面に差し替える。
