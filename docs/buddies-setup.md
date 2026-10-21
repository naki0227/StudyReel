# 勉強仲間：CloudKit の準備

勉強仲間は CloudKit を使います。コンテナは iCloud バックアップと同じ `iCloud.com.ni.StudyTimerAndVideo`。
以下は Apple のサイトで行う作業です。**勉強仲間を入れた版を App Store に出す前に、電気通信事業の届出（docs/telecom-filing/）も済ませること。**

## 1. App ID の機能（Capabilities）

https://developer.apple.com/account/resources/identifiers → `com.ni.StudyTimerAndVideo`

| 機能 | entitlements のキー | 使うところ |
| --- | --- | --- |
| iCloud（CloudKit にもチェック） | `com.apple.developer.icloud-services` に `CloudKit` | グループ・申請・人数・通報 |
| Push Notifications | `aps-environment` | スタンプなどの通知（CloudKit の静かなプッシュ） |
| Sensitive Content Analysis | `com.apple.developer.sensitivecontentanalysis.client` | 裸などの写真を送らない・出さない |
| Declared Age Range | `com.apple.developer.declared-age-range` | 18歳未満なら写真を初期オフ |

entitlements にはすべて書いてあります。TestFlight のワークフローは自動署名（`-allowProvisioningUpdates`）なので、App ID に足りない機能があれば足してくれる想定です。
署名で止まったら、上の画面で手動でチェックを入れてから流し直してください。

## 2. 開発環境でスキーマを作る

**かんたんな方法**：`docs/cloudkit/schema.ckdb` に、使うレコード型・インデックス・セキュリティロール（3 と 4 の内容）をまとめてあります。
Mac で次を実行すると、開発環境にそのまま入ります（CloudKit Console の Settings → Tokens で管理トークンを作っておく）。

```sh
xcrun cktool save-token --type management          # 管理トークンを貼る
xcrun cktool export-schema --team-id <チームID> --container-id iCloud.com.ni.StudyTimerAndVideo --environment development > /tmp/current.ckdb   # 念のため今のスキーマを保存
xcrun cktool validate-schema --team-id <チームID> --container-id iCloud.com.ni.StudyTimerAndVideo --environment development --file docs/cloudkit/schema.ckdb
xcrun cktool import-schema --team-id <チームID> --container-id iCloud.com.ni.StudyTimerAndVideo --environment development --file docs/cloudkit/schema.ckdb
```

入ったら 5 の本番への反映に進みます（3 と 4 は schema.ckdb に入っているので、コンソールで確かめるだけ）。

**手で作る方法**：

CloudKit は、開発環境（Development）で初めてレコードを書いたときに型ができます。Xcode からデバッグ実行した端末で、次を一通り行います。

| 操作 | できる型 | データベース |
| --- | --- | --- |
| グループを作る | `BuddyGroup`、`BuddyMember` | プライベート（共有ゾーン） |
| スタンプを送る | `BuddyStamp` | 共有ゾーン |
| オーナーが写真をオンにして、1コマ出す | `BuddyPhoto` | 共有ゾーン |
| 別のアカウントで参加を申請する | `BuddyJoinRequest` | 公開 |
| 許可する・断る | `BuddyJoinApproval`、`BuddyJoinDenial` | 公開 |
| 資格を選んで録画を始める | `BuddyPresence` | 公開 |
| 通報する（写真つきでも1回） | `BuddyReport` | 公開 |
| （開発者がコンソールで作る） | `BuddyPhotoBan`（フィールド `note` など何か1つ） | 公開 |

## 3. インデックス

https://icloud.developer.apple.com/dashboard → コンテナ → Development → Schema → Indexes

| レコード型 | フィールド | 種類 | なぜ |
| --- | --- | --- | --- |
| `BuddyJoinRequest` | `token` | QUERYABLE | オーナーが申請を一覧する |
| `BuddyJoinRequest` | `recordName` | QUERYABLE | クエリに必要 |
| `BuddyPresence` | `until` | QUERYABLE | 勉強中の人数を数える |
| `BuddyPresence` | `recordName` | QUERYABLE | クエリに必要 |
| `BuddyReport` | `recordName` | QUERYABLE | コンソールで一覧する |
| `BuddyReport` | `createdTimestamp` | SORTABLE | 新しい順に見る |

## 4. セキュリティロール（公開データベース）— 必ず変える

Schema → Security Roles。公開データベースは、初めは「だれでも読める」設定です。

| レコード型 | `_world` | `_icloud` | `_creator` | 理由 |
| --- | --- | --- | --- | --- |
| `BuddyReport` | **なし** | Create | なし | 通報（写真を含む）を開発者以外が読めないようにする |
| `BuddyPhotoBan` | Read | **なし** | なし | 利用者が勝手に他人を締め出せないようにする。作るのは開発者だけ |
| `BuddyPresence` | Read | Create | Write | 人数を数えるのに読む。名前は入っていない |
| `BuddyJoinRequest` / `Approval` / `Denial` | Read | Create | Write | 今のまま |

## 5. 本番環境に反映する

Schema → 「Deploy Schema Changes...」で Production に反映し、**Production 側のセキュリティロールも 4 と同じになっているか確かめる**。
TestFlight と App Store のアプリは Production を使うので、これをしないと勉強仲間が動きません。型やフィールドを足したときも毎回必要です（消すことはできません）。

## 仕組みのメモ

- グループ1つ = オーナーのプライベート DB のゾーン1つ（`buddies-` で始まる）。ゾーン全体を CKShare で共有する
- 参加者は共有 DB から読み書きする。抜けるときは共有 DB からそのゾーンを消す
- 参加の申請と許可は公開 DB。iOS 26 の参加申請 API は iOS 18 で使えないので自前で作っている
  - 申請者が `BuddyJoinRequest`（`req-<招待トークン>-<自分>`）を書く
  - オーナーが許可すると共有に参加者を足し、`BuddyJoinApproval`（`ok-<申請>`）に共有 URL を書く。断ると `BuddyJoinDenial`（`no-<申請>`）
- 通知：プライベート DB と共有 DB に `CKDatabaseSubscription`（静かなプッシュ）を置き、受け取ったら読み直して端末の中で通知を出す
- 資格ごとの人数：勉強中で資格を選んでいる人だけ `presence-<利用者番号>`（資格と終わる目安だけ）を置き、止めたら消す
- 写真：`photo-<日付>-<利用者番号>`（1人1日1枚）。24時間で期限が切れ、オーナーか本人の端末が消す。画像は見るときだけ取ってきて、端末の Caches に24時間だけ置く
- 開発者には共有の中身は見えない。見えるのは公開 DB（申請、人数、通報）だけ
- CI のシミュレーターは iCloud にサインインしていないので、共有の動きは TestFlight で2台・2アカウント使って確かめる
- 通報の受け方と締め出し方は docs/buddies-moderation.md
