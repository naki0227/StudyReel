# iCloudバックアップの準備（無料・最初からオン）

記録（backup.json）とサムネイル・動画を、iCloud Drive のアプリ専用フォルダ（ファイルアプリには出ない）にコピーします。CloudKit は使いません。

## Xcode でやること

1. ターゲット **StudyTimerAndVideo** → **Signing & Capabilities** → **+ Capability** → **iCloud** を追加
2. **Services** で **iCloud Documents** にチェック（CloudKit は不要）
3. **Containers** で `iCloud.com.ni.StudyTimerAndVideo` を選ぶ（なければ「+」で作成）

エンタイトルメント（`StudyTimerAndVideo/StudyTimerAndVideo.entitlements`）にはすでに次を書いてあります。Xcode が同じ値を使っていれば、そのままで大丈夫です。

- `com.apple.developer.icloud-container-identifiers` = `iCloud.com.ni.StudyTimerAndVideo`
- `com.apple.developer.icloud-services` = `CloudDocuments`
- `com.apple.developer.ubiquity-container-identifiers` = `iCloud.com.ni.StudyTimerAndVideo`

## Apple Developer サイトでやること

- Identifiers → `com.ni.StudyTimerAndVideo` → **iCloud** を有効にして、上のコンテナを割り当てる
- 自動署名なら Xcode が代わりにやってくれます。手動署名ならプロビジョニングプロファイルを作り直す

## 動き

- 設定 → iCloudバックアップ：自動でバックアップ／今すぐバックアップ／バックアップから戻す
- 自動は 1日1回まで（アプリが裏に回ったとき、記録を保存したあと）
- 戻すときは今ある記録を消さず、バックアップにしかない記録（id で判定）・タグ（名前）・目標（日付）だけを足す
- 全部録画の動画は大きいので、iCloud の空き容量が足りないと失敗します

## 確かめ方

実機で iCloud にサインインした状態で「今すぐバックアップ」→ アプリを消して入れ直す →「バックアップから戻す」。

## ファイルアプリでの表示と共有

Info.plist の `NSUbiquitousContainers` で、iCloud Drive に「StudyReel」フォルダが出るようにしている。
中の `StudyReel/Media` に動画とサムネイルが入るので、ファイルアプリでフォルダを長押し →「共有」から家族に共有できる。
フォルダがすぐ出ないときは、ビルド番号を上げてから入れ直す（iOS はビルド番号が変わったときに読み直す）。
