# 勉強仲間：CloudKit の準備

勉強仲間は CloudKit を使います。コンテナは iCloud バックアップと同じ `iCloud.com.ni.StudyTimerAndVideo`。
アプリ側の entitlements には `CloudKit` を追加済みです。以下は Apple のサイトで一度だけ行う作業です。

## 1. App ID で CloudKit を有効にする

1. https://developer.apple.com/account/resources/identifiers を開き、`com.ni.StudyTimerAndVideo` を選ぶ
2. iCloud の「Edit」で **CloudKit** にチェック（iCloud Documents はそのまま）
3. コンテナ `iCloud.com.ni.StudyTimerAndVideo` が選ばれていることを確かめて保存
4. プロビジョニングプロファイルを作り直す（testflight.yml は毎回取り直すので、そのまま流せば OK）

## 2. 開発環境でスキーマを作る

CloudKit は、開発環境（Development）で初めてレコードを書いたときに型が自動で作られます。
Xcode からデバッグ実行した端末で、次を一通り行ってください。

- 勉強仲間のグループを作る（`BuddyGroup`、`BuddyMember` ができる）
- 別のアカウントの端末から参加を申請する（`BuddyJoinRequest`）
- 許可する・断る（`BuddyJoinApproval`、`BuddyJoinDenial`）
- スタンプを送る（`BuddyStamp`）

## 3. インデックスを追加する

https://icloud.developer.apple.com/dashboard → コンテナ → Development → Schema → Indexes

| レコード型 | フィールド | 種類 |
| --- | --- | --- |
| `BuddyJoinRequest` | `token` | QUERYABLE |
| `BuddyJoinRequest` | `recordName` | QUERYABLE |

`token` がないと、オーナーが申請を一覧できません。

## 4. 本番環境に反映する

Schema → 「Deploy Schema Changes...」で Production に反映します。
**TestFlight と App Store のアプリは Production を使うので、これをしないと勉強仲間が動きません。**
型やフィールドを追加したときも、毎回このデプロイが必要です（消すことはできません）。

## 仕組みのメモ

- グループ1つ = オーナーのプライベート DB のゾーン1つ（名前は `buddies-` で始まる）。ゾーン全体を CKShare で共有する
- 参加者は共有 DB から読む・書く。抜けるときは共有 DB からそのゾーンを消す
- 参加の申請と許可は公開 DB を使う。iOS 26 の CloudKit の参加申請 API は iOS 18 で使えないため、自前で作っている
  - 申請者が `BuddyJoinRequest`（`req-<招待トークン>-<自分>`）を書く
  - オーナーがトークンで探して、許可すると共有に参加者を追加し、`BuddyJoinApproval`（`ok-<申請>`）に共有 URL を書く
  - 申請者はそれを見つけて共有を受け入れる。断ると `BuddyJoinDenial`（`no-<申請>`）
- 開発者には共有の中身は見えません。見えるのは公開 DB の申請（ニックネーム、4桁の番号、CloudKit の匿名 ID）だけ
- CI のシミュレーターは iCloud にサインインしていないので、共有の動きは TestFlight で2台・2アカウント使って確かめる
