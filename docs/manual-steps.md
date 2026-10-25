# 手でやること（App Store Connect・Apple Developer）

コードやワークフローでは変えられないもの。docs/competitors.md の「よくする順番」から出てきたもの。

## 値上げ（10/28）を止める
App Store Connect → アプリ → サブスクリプション → 月額・年額それぞれ →「サブスクリプション価格」→ 予定されている価格の変更を削除。
評価とお試しの数が出てから、`pro-report.yml` の数字で決め直す。

## Mac で配る（作り直しは要らない）
App Store Connect → アプリ →「価格および配信状況」→「iPhone および iPad アプリの Apple シリコン Mac での配信状況」→ 配信する。
- カメラは Mac の内蔵カメラで動く。ライブアクティビティ・ウィジェットの一部は Mac では出ない
- 出したあと、Mac で一度デモではなく本当に録画して、保存・共有まで通ることを確かめる

## 録画中のアプリ制限（FamilyControls）
実装の前に、Apple に配布用の権限を申請する（開発中は申請なしで試せるが、TestFlight・App Store には申請が通らないと出せない）。
1. https://developer.apple.com/contact/request/family-controls-distribution から申請（アプリの説明：録画中だけ、本人が選んだ SNS などを開けないようにする。保護者用ではなく本人用）
2. 通ったら、Certificates, Identifiers & Profiles → Identifiers → com.ni.StudyTimerAndVideo に「Family Controls」が付く
3. 付いたら知らせてください。Screen Time の DeviceActivity の拡張と一緒に実装します

## 中国（本土）のストア
中国本土のストアに新しく出すには、ICP の届出番号が要る。StudyReel は自前のサーバーを持たない（iCloud だけ）が、届出が要るかは Apple の案内で確かめる。
- 簡体字は、シンガポール・マレーシア・各国の中国語の人にも届くので、中国本土に出さなくても意味がある
- 「価格および配信状況」で中国本土が入っているかを確かめ、入っていて届出がないなら外す

## 1.9 を出すとき
- 2台で保護者・塾の共有を試す（docs/family-and-school.md の手順）
- appstore/release.yml の version を 1.9、build を新しい番号に、whats_new を全言語（ja・ko・zh-Hans・zh-Hant・en-US）に
- company-web の PR #31（プライバシーポリシーの共有の節）をマージし、日付を出した日にする
- マージするとファミリー共有がオンになる（一度オンにすると戻せない）
