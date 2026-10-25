# StudyReel 新機能の技術調査（iOS）

調査日：2026-10-25
対象：このリポジトリ（読み取りのみ。ビルドはしていません。コードを読んだ結果です）

---

## 0. 前提として分かったこと（全機能に関係します）

| 項目 | 内容 | 場所 |
| --- | --- | --- |
| デプロイメントターゲット | **iOS 18.0**（アプリ・ウィジェット・テストのすべて） | `StudyTimerAndVideo.xcodeproj/project.pbxproj:526, 583, 660, 678` |
| プロジェクト形式 | `objectVersion = 77`。**PBXFileSystemSynchronizedRootGroup**（フォルダ同期）を使っています。新しいファイルは置くだけでそのフォルダのターゲットに入ります。**アプリとウィジェットの両方に入れるファイルは、pbxproj の `membershipExceptions` を手で書く必要があります**（Mac がないので、CI で初めて確認できます） | `project.pbxproj:6, 63-117` |
| Swift | `SWIFT_VERSION = 5.0`（Swift 6 の厳密な並行性チェックはオフ） | `project.pbxproj:441` ほか |
| Background Modes | `remote-notification` だけ。**audio はありません** | `StudyTimerAndVideo/Info.plist` の `UIBackgroundModes` |
| Live Activity | `NSSupportsLiveActivities = true` | `StudyTimerAndVideo/Info.plist` |
| App Group | `group.com.ni.StudyTimerAndVideo`（アプリ・ウィジェット共通） | 両方の entitlements |
| CloudKit | `iCloud.com.ni.StudyTimerAndVideo`。SwiftData は CloudKit 同期しない設定（`cloudKitDatabase: .none`） | `StudyTimerAndVideoApp.swift:27` |
| 録画で音声 | **AVCaptureSession にマイク入力はありません**（映像の入力と `AVCaptureVideoDataOutput` だけ）。`AVAssetWriter` も映像トラックだけ | `Utilities/TimeLapseRecorder.swift:94-129, 321-367` |
| 「録画なし」モード | `RecordingMode.off`（「録画なし」）がすでにあります | `Utilities/TimeLapseRecorder.swift:5-24` |
| 環境音 | 雨の音・集中ノイズ（BrownNoise）・BGM 4曲を録画画面で流す `StudyMusicPlayer` がすでにあります | `Utilities/StudyMusicPlayer.swift` |
| App Intents | ウィジェット拡張の `StopTimerIntent` だけ。App Shortcuts・Control・Focus Filter はありません | `StudyReelWidget/StudyReelWidget.swift:100-107` |
| 通知のデリゲート | `UNUserNotificationCenterDelegate` を設定している場所がありません。**アプリが前面にあるとき、ローカル通知はバナーが出ません** | grep で該当なし。`Utilities/OrientationLock.swift:6-19` の AppDelegate にもなし |
| 熱・電池・空き容量 | `ProcessInfo.thermalState`、`isLowPowerModeEnabled`、`systemPressureState`、`volumeAvailableCapacity…` は**どこでも使っていません**（後述 8 章） | grep で該当なし |

「Watch」という名前（`WatchCloud.swift`、`WatchView.swift`）は Apple Watch ではなく、**保護者・塾の「見守り」機能**です。

---

## 1. ポモドーロ（25/5・50/10・自由設定）と録画の連動

### 1-1. 今の録画の一時停止と再開

- `TimeLapseRecorder.pause()`（`Utilities/TimeLapseRecorder.swift:186-191`）は `isCapturing = false` にして `lastFramePTS = nil` にします。
- `resume(elapsedNow:)`（同 `:194-202`）は `isCapturing = true` に戻します。`elapsedNow` を渡したときは `elapsedOffset` を直して、撮れていなかった時間も動画の文字に足します。
- `captureOutput`（同 `:258-297`）は **`activeSeconds` に「前のフレームとの差」だけを足していきます**。一時停止の後は `lastFramePTS` が nil なので、止まっていた間は足されません。
  - タイムラプスは `activeSeconds` が `interval` 進むごとに1枚書きます（`:274-281`）。
  - 全部録画は `activeSeconds` をそのまま動画の時刻にします（`:282-293`）。
- つまり **`pause()` / `resume()` を呼ぶだけで、休憩の時間は動画に入りません**。「タイムラプスに集中時間だけを入れる」は、今の録画の仕組みのままでできます。
- 動画に入る経過時間の文字は `elapsedOffset + activeSeconds`（`:389`）です。`resume()` を `elapsedNow` なしで呼べば、**集中時間だけの合計**になります。ポモドーロではこちらが合っています。
- 呼び出し側は `ContentView.togglePause()`（`ContentView.swift:637-666`）です。タイマーとストップウォッチを止め、`recorder.pause()`、`music.hold(true)`、`updateLiveActivity()` を呼んでいます。
- アプリが裏に回ったときは `handleScenePhase`（`:737-752`）→ `stopRecordingWhileAway()`（`:754-758`）で録画だけ止め、戻ったら「録画が止まっていました」のカード（`:465-501`）を出します。勉強時間は数え続けます。

### 1-2. 今のタイマーの問題点

- `TimerViewModel`（`ViewModels/TimerViewModel.swift`）は **1秒ごとに `remaining -= 1` する方式**です。裏に回った時間は、前面に戻ったとき（`didBecomeActive`）にまとめて引きます（`:59-71` 付近）。
- 裏にいる間は `onFinish` が呼ばれません。戻ってから次の1秒で終了します。
- 1つのタイマーならこれで足ります。ポモドーロは「集中 → 休憩 → 集中…」と切り替わるので、**裏にいる間に区切りを何回またいだかを、時計の時刻から計算し直す必要があります**。1秒ずつ数える方式のままでは合わなくなります。

### 1-3. おすすめのやり方

**(1) 時刻から計算するポモドーロの仕組み `PomodoroEngine` を新しく作る**（`ViewModels/PomodoroEngine.swift`）

- 持つもの：`plan`（例：集中 25分・休憩 5分・4回、長い休憩は任意）、`startedAt`、一時停止した時間の合計。
- `phase(at: Date)` が「今は何回目の集中／休憩で、何時に終わるか」を返します。1秒ごとの Timer は画面表示に使うだけにします。
- 区切りが来たら、集中 → 休憩で `recorder.pause()`、休憩 → 集中で `recorder.resume()`（`elapsedNow` は渡さない）を呼びます。
- ユーザーの一時停止（`isPaused`）、アプリを離れたことによる停止（`stoppedWhileAway`）、休憩の3つを別々の状態として持ちます。今の `togglePause()` と `stopRecordingWhileAway()` は「一時停止中なら何もしない」という条件で動いているので（`ContentView.swift:755, 763`）、**休憩も同じように扱う条件を足します**。
  - 休憩中にアプリへ戻ったときは、再開のカードを出しません。
  - 休憩が終わった時点でアプリが前面にあれば、自動で `resume()` します。
  - 裏にいたあいだに集中が始まっていたときは、今と同じ「録画を再開」カードを出します。
- 保存する勉強時間（`pendingDuration`、`ContentView.swift:669-670`）は **集中時間の合計**にします。今は `totalSeconds - remaining` で計算しています。

**(2) 休憩中のカメラ**

- 休憩の間も `AVCaptureSession` は動き続けます。`pause()` はフレームを捨てるだけだからです。
- 5〜10分の休憩なら、プレビューを止めると電池と発熱が減ります。`session.stopRunning()` を休憩の初めに呼び、`startRunning()` を集中の前に呼びます。どちらも `videoQueue` ではなく、別のキューで呼びます。
- 再開には 0.5〜1 秒かかります。その間にフレームが来なくても、`activeSeconds` は差分で数えているので問題ありません。

**(3) 休憩の通知（裏にいるとき・画面ロック中）**

- 区切りの時刻ごとに `UNTimeIntervalNotificationTrigger` を**前もってすべて予約**します。4回なら最大8件ほどです。識別子は `studyreel.pomodoro.<n>` のようにします。
  - アプリが止まっていても通知は出ます。
  - 一時停止・終了・中断のときは `removePendingNotificationRequests` で消します。再開したら、ずれた時刻で予約し直します。
- **前面にいるときにも通知を見せるには**、`UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:)` で `[.banner, .sound]` を返す必要があります。今は設定がないので、AppDelegate（`Utilities/OrientationLock.swift:6`）か App の init で `UNUserNotificationCenter.current().delegate` を設定します。
  - 録画画面では、通知より**画面の中の表示と音**（`AudioServicesPlaySystemSound` か短い効果音）のほうが分かりやすいです。
- 通知の許可は、今は「静かなリマインダー」（`Utilities/StudyNotificationManager.swift:62-76`）と勉強仲間（`Buddies/BuddyNotifier.swift:18-23`）で求めています。**ポモドーロを初めて選んだときにも許可を求めます**。
- `interruptionLevel = .timeSensitive` にすると、集中モード中でも出やすくなります。ただし **Time Sensitive Notifications の capability（entitlement）を追加**する必要があります。休憩の合図は「時間に関わる通知」なので、使い方としては妥当です。

**(4) Live Activity に集中・休憩の残り時間を出す**

- `StudyActivityAttributes.ContentState`（アプリ側 `Models/StudyActivityAttributes.swift:7-16`、ウィジェット側 `StudyReelWidget/StudyActivityAttributes.swift:7-16`。**2か所に同じ定義があり、両方を合わせて変えます**）に次を足します。
  - `phase: String?`（focus / shortBreak / longBreak）
  - `round: Int?`、`totalRounds: Int?`
  - `phaseEnd: Date?`、`nextPhaseEnd: Date?`
- **追加するのは必ず Optional にします**。アプリを更新したとき、前の版で始まっていた Activity とデコードの互換を保つためです。
- **注意：画面ロック中、アプリは止まっています。**Background Modes は remote-notification だけで、ActivityKit のプッシュ更新を送るサーバーもありません（CloudKit だけです）。そのため、**区切りの時刻にアプリから Live Activity を更新することはできません**。対策は次の3つです。
  1. `ActivityContent(state:staleDate: phaseEnd)` を渡します。時刻を過ぎるとシステムが `context.isStale = true` で描き直すので、ビュー（`StudyReelWidget/StudyLiveActivity.swift:92-107` の `timeText`）で `isStale` なら「休憩の時間です（タップで開く）」を出します。
  2. 次の区切りまでのカウントダウンは今と同じ `Text(timerInterval:countsDown:)` を使います。`ProgressView(timerInterval:)` を足すと進み具合も見せられます。
  3. 環境音を裏でも流す場合（7章で `audio` モードを付けた場合）は、アプリが動き続けるので、区切りで `activity.update` できます。ただし**音を流していない人には効かない**ので、1 と 2 を基本にします。
- iOS 26 の **AlarmKit** はカウントダウンと「必ず鳴るアラーム」を Live Activity つきで出せます。消音中や集中モード中でも鳴ります。ターゲットが 18 なので `if #available(iOS 26, *)` での追加になります。今の Live Activity と二重に出てしまうので、使うなら「休憩の終わりのアラームだけ」に限るのが安全です。
- Live Activity は**最長 8 時間**動き、その後ロック画面に最大 4 時間残ります（ActivityKit のドキュメント）。50/10 を何回もくり返すと 8 時間を超えることがあるので、超えたら作り直す処理を入れておきます。
- 停止ボタンは今 `studyreel://stop` の Link です（`StudyLiveActivity.swift:7`、`ContentView.swift:140-145`）。iOS 17 以降は **`LiveActivityIntent` を使った Button** で「休憩を飛ばす」「一時停止」を置けます。ただし、ロック中にアプリが起こされてもカメラは使えません。録画の再開は、アプリを開いたときにしかできません。

**(5) ウィジェットとの関係**

- `pomodoro_timer_end_timestamp`（`ContentView.swift:812-833`、`StudyReelWidget.swift:13-29`）は**タイマーの終わる時刻を1つだけ**持ちます。
- 録画画面は、この値が消えたら停止します（`syncWithWidgetStopState`、`ContentView.swift:826-833`）。ポモドーロでは**「全体の終わり」を入れ続けるか、別のキー（`pomodoro_plan`）を作る**必要があります。休憩の終わりを入れてしまうと、休憩の区切りで止まってしまいます。

### 1-4. 変えるファイル

- `ViewModels/PomodoroEngine.swift`（新規）
- `ContentView.swift`（開始・一時停止・裏に回ったとき・保存・Live Activity の更新・休憩中の画面）
- `Utilities/TimeLapseRecorder.swift`
  - 休憩中に `stopRunning` / `startRunning` する関数を足します。
  - 再開したとき `faceTracker` の `segment` を進めます（休憩の前後で顔の枠がなめらかにつながってしまうのを防ぎます）。
- `Utilities/StudyNotificationManager.swift`（区切りの通知の予約と取り消し、許可）
- `Utilities/OrientationLock.swift` の AppDelegate（通知のデリゲート）
- `Models/StudyActivityAttributes.swift` と `StudyReelWidget/StudyActivityAttributes.swift`（ContentState）
- `Utilities/StudyLiveActivityController.swift:14-58`（state を作る部分）
- `StudyReelWidget/StudyLiveActivity.swift`（休憩中の色と文言、`isStale` のときの表示）
- `Views/StartView.swift`（モードを選ぶ画面）、`Models/Mode.swift`（`.pomodoro(plan)` を足すか、Mode とは別に持つか）
- `Models/SessionBootstrap.swift`、`Models/CurrentSessionDraft.swift`（ウィジェットや Intent から始めるときにも plan を渡す）
- `Utilities/SessionRecovery.swift`（アプリが落ちたときの控えに plan とフェーズを足す）
- 任意：`Models/SwiftDataModels.swift` に `focusRounds: Int?` を足す。足すなら `Utilities/CloudBackup.swift:107, 198, 302` も合わせて変えます。
- 文言：`*.lproj` と `tools/l10n/check.py`

### 1-5. 注意点と審査のリスク

- **画面をロックすると録画は止まります**（iOS ではカメラは前面でしか使えません）。ポモドーロにしても「机に置いて開いたまま」という前提は変わりません。休憩中に SNS を見に行ったら、集中が始まるときに戻ってもらう必要があります。通知の文言で案内します。
- **無音の音声を流してアプリを動かし続けるのは、審査で却下されます**（ガイドライン 2.5.4。バックグラウンドの機能は本来の目的にしか使えません）。
- Time Sensitive の通知を宣伝などに使うと却下されます。休憩の合図だけに使います。

---

## 2. カメラを使わないセッション（タイマーだけ）

### 2-1. 今の状態

- **「録画なし」（`RecordingMode.off`）がすでにあります。**`isRecordingVideo == false` のときは `recorder.start` を呼ばず（`ContentView.swift:609-617`）、終わったら保存画面だけを出します（`:689-691`）。保存するときの `videoFileName` / `thumbnailFileName` は nil です。
- 手動で記録を足す画面 `Views/ManualAddView.swift` もあり、動画のない記録はもう作られています。
- ただし、**「録画なし」でもカメラは動いています。**`CameraPreview`（`Views/CameraPreview.swift:54-65`）は、モードに関係なく `recorder.startSession` を呼びます。
  - カメラ使用中の緑のインジケーターが付いたままになり、電池も減ります。
  - 「録画していないのにカメラが動いている」状態は、ガイドライン 2.5.14（記録するときは同意と分かりやすい表示が必要）の考え方から見て、誤解を招きます。
- ホームから始めるときは、**カメラと写真の両方が許可されていないと、録画なしで始まります**（`Views/StartView.swift:556-580`）。許可が「未設定」なら、許可のダイアログが先に出ます。

### 2-2. 動画がない記録の扱い（`videoFileName` が nil）

| 場所 | 扱い |
| --- | --- |
| サムネイル `Views/SessionThumbnail.swift:10-28` | nil なら教科名のグラデーションを表示。問題なし |
| 詳しい画面 `Views/SessionDetailView.swift:100-113` | 動画がなければサムネイルを表示。問題なし |
| 統計 `Views/StudyStatsView.swift` / カレンダー | `duration` だけで計算するので、動画がなくても数えます |
| 連続日数 `Models/GoalModels.swift:218-226`、`Buddies/BuddyProfile.swift:198-` (`BuddyTotals`) | 記録の日付だけを見ます。動画がなくても連続に数えます |
| 勉強仲間・見守り `BuddyCloud.updateTotals`（`:498-503`）、`WatchCloud.pushStatus` | `BuddyTotals` を使うので同じ扱い |
| 1週間の Vlog `Views/WeeklyVlogView.swift:25`、`Utilities/WeeklyVlogMaker.swift:66` | 動画のある記録だけ。ない日は飛ばします |
| 勉強仲間の写真 `Views/Buddies/BuddyPhotoViews.swift:214, 233` | `videoFileName != nil` の記録だけ選べます |
| バックアップ `Utilities/CloudBackup.swift:107, 175, 302` | Optional のまま扱っています |
| レビューのお願い `Views/StartView.swift:165` | `latestHasVideo` を見ています |

**結論：記録のデータ側は、動画のない記録にもう対応しています。**足りないのは「カメラを動かさない入口と画面」だけです。

### 2-3. おすすめのやり方

- 録画画面を出すときに、録画なしならプレビューを作らないようにします。
  - `ContentView` の `CameraPreview(...)`（`ContentView.swift:71`）を `recordingMode != .off` のときだけ置きます。録画なしのときは、`fallbackPreview` に似た落ち着いた背景と大きなタイマーを出します。
  - `TimeLapseRecorder` は `init` の中ですぐ `setupSession()` を呼びます（`TimeLapseRecorder.swift:69-74`）。デバイスに入力をつなぐだけなので、カメラのランプは付きません（付くのは `startRunning` のときです）。それでも、**録画なしのときは `@StateObject` の生成を遅らせるか、`setupSession` を `startSession` の中に移す**と、より確実です。
- モードを選ぶチップ（`ContentView.swift:508-530`）で、開始した後に録画なしからタイムラプスへ切り替えられないことを確かめます（今は開始前だけ表示されます）。
- 「カメラを許可していない人」もタイマーだけで使えるように、ホームに「タイマーだけで始める」の入口を足します。許可のダイアログを出さずに始めます（`StartView.startSession(recordTimelapse: false)`）。
- 記録を区別したいなら、`StudySession` に `captureKind: String?`（timelapse / full / none / manual）を足します。SwiftData で Optional を足すだけなら軽い移行で済みます。CloudKit 同期はしていないので、条件はゆるいです。

### 2-4. 変えるファイル

`ContentView.swift`、`Views/CameraPreview.swift`、`Utilities/TimeLapseRecorder.swift`（遅らせて作る）、`Views/StartView.swift`（入口）、任意で `Models/SwiftDataModels.swift` と `Utilities/CloudBackup.swift`。

### 2-5. 審査のリスク

低いです。むしろ、**カメラを許可しなくても主な機能（タイマー）を使える**ことは、ガイドライン 5.1.1（ユーザーデータの扱い）の考え方に合っていて、審査ではプラスになります。

---

## 3. 1年の勉強ヒートマップ（GitHub 風）と共有カード

### 3-1. 今あるもの

- 統計の画面 `Views/StudyStatsView.swift` には、週・月・年の期間（`StatsPeriod`、`:405-`）と、Swift Charts の棒グラフ（`:136-155`）があります。
  - 年を選ぶと、月ごとの12本の棒になります（`:306-311`）。
  - 集計は `items.filter { … }` を日数ぶんくり返すので、**記録の数 × 日数**の計算量になります（`:290-312`）。365日に広げると重くなります。
- カレンダー `Views/CalendarView.swift:116-135` は、**1か月の濃淡（intensity = 0.25 + 0.75 × その日 / 月の最大）**をすでに描いています。色の付け方はここに合わせられます。
- 共有カード：
  - `Views/StudyShareView.swift:307-316`：`ImageRenderer(content: card.frame(width: 360))`、`scale = max(displayScale, 3)` → `uiImage` → ShareLink。カード本体は `StudyShareCard`（`:382-470`）で、7日の棒（`dayBars`）を手描きしています。
  - `Views/GoalShareView.swift:175-180`：360×640、scale 3。
  - 種類の選択は `ShareKind`（`StudyShareView.swift:319-333`：期間・教材・教科）です。

### 3-2. おすすめのやり方

**(1) 集計の関数（`Utilities/StudyHeatmap.swift`、新規）**

- `sessions` を1回だけ回して、`[Date(startOfDay): Int]` の辞書を作ります。
- 53週×7日のマス（列＝週、行＝曜日。`Calendar.current.firstWeekday` を守る）を返します。
- 濃さは5段階にします。基準は「その年の、勉強した日の中央値」か、時間で決めた区切り（0 / 〜30分 / 〜1時間 / 〜2時間 / 2時間〜）にします。最大値を基準にすると、1日だけ長い日があったときに全体が薄くなるので、**時間の区切りがおすすめ**です。
- テストが書きやすいので、`StudyTimerAndVideoTests` に追加できます。

**(2) 画面**

- Swift Charts の `RectangleMark`（x: 週、y: 曜日）でも描けます。ただし 371 個のマークになるので、**`Canvas` で描くほうが軽く、`ImageRenderer` でも確実です**。
- 統計の年表示（`period == .year`）のときだけ、棒グラフの下に置きます。
- 横幅は 360pt で 53 列なので、1マスは約 5.5pt（間隔 1pt）です。iPhone の画面では少し小さいので、画面では横スクロールにして最新の週を右端に置く方法もあります（共有カードは1枚に収めます）。
- マスをタップしたら、その日の合計を出します（`CalendarView` の選んだ日へ移動してもよいです）。
- VoiceOver には、マスごとではなく「今年 120日勉強、合計 300時間」のようにまとめて読ませます（371 個を読ませると使えません）。

**(3) 共有カード**

- `ShareKind` に `.year` を足し、`StudyShareCard` と同じ作りの `YearHeatmapCard` を作ります。中身は、年・合計時間・勉強した日数・最長の連続日数・ヒートマップです。
- `ImageRenderer` はそのまま使えます（Canvas も Swift Charts も描けます）。注意点は次のとおりです。
  - 縦長の 1080×1920 にするなら、`frame(width: 360, height: 640)` と `scale = 3` にします（GoalShareView と同じです）。
  - `ReelTheme` のフォントはアプリに入っているフォントなので描けます。
  - `ImageRenderer` は `@MainActor` で呼びます（今と同じです）。
- 写真のサムネイルは入れません。ヒートマップは顔が写らないので、モザイクの心配がありません。

### 3-3. 変えるファイル

`Utilities/StudyHeatmap.swift`（新規）、`Views/StudyHeatmapView.swift`（新規）、`Views/StudyStatsView.swift`、`Views/StudyShareView.swift`（`ShareKind` とカード）、文言、テスト。Pro にするかどうかは `docs/pro-value.md` の方針に合わせて決めます（統計の教科別はペイウォールを出す場面に入っています）。

### 3-4. リスク

技術的にも審査の面でも低いです。気をつけるのは、記録が数千件になったときの計算時間です。`@Query` から毎回作り直すと重いので、`.task(id: sessions.count)` で作り直しを減らします。

---

## 4. iOS から勉強を始める（App Intents・ショートカット・コントロール・ロック画面・アクションボタン・集中モード）

### 4-1. 今ある入口

- ウィジェットのボタンは `studyreel://start?mode=timer&minutes=25&record=1` の Link です（`StudyReelWidget.swift:65-78, 232-257`）。
- アプリ側は `StartView.handleIncomingURL`（`Views/StartView.swift:608-631`）で受けて、`SessionBootstrap(autoStart: true)` で**すぐ録画を始めます**。
- App Group の下書き `CurrentSessionDraft`（`Models/CurrentSessionDraft.swift:9-55`）を `consumePendingSessionDraftIfNeeded`（`StartView.swift:594-606`）で読む仕組みもあります。`didBecomeActive` のときにも読みます（`:255-258`）。**Intent から下書きを書いてアプリを開けば、そのまま始められます。**

### 4-2. おすすめの組み立て

**(A) `StartStudyIntent`（アプリのターゲットに置く）**

```swift
struct StartStudyIntent: AppIntent {
    static let title: LocalizedStringResource = "勉強を始める"
    static let openAppWhenRun = true            // iOS 18 で使える。iOS 26 以降は supportedModes = .foreground(.immediate) でもよい
    @Parameter(title: "時間") var preset: StudyPreset   // AppEnum: 25分 / 50分 / 90分 / ストップウォッチ / ポモドーロ
    @Parameter(title: "録画", default: true) var record: Bool
    @MainActor func perform() async throws -> some IntentResult {
        CurrentSessionDraftStore().save(.timer(durationSeconds: preset.seconds, source: .shortcut, shouldRecordTimelapse: record))
        return .result()
    }
}
```

- `SessionLaunchSource` に `.shortcut` を足します（`CurrentSessionDraft.swift:3-7`）。
- `openAppWhenRun` は iOS 16 から使えます。iOS 26 では `supportedModes`（`.foreground(.immediate)` など）が増えました（developer.apple.com の `AppIntent/supportedModes`、iOS 26.0〜）。ターゲットが 18 なので、**まずは `openAppWhenRun` を使います**。
- `perform` はアプリが前面に出る前に動くので、カメラの操作は `perform` の中ではしません。**下書きを書くだけ**にして、`StartView` の `didBecomeActive` で読ませます。今の仕組みがそのまま使えます。

**(B) App Shortcuts（「StudyReel で勉強を始める」）**

```swift
struct StudyReelShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartStudyIntent(),
                    phrases: ["\(.applicationName)で勉強を始める", "\(.applicationName)で\(\.$preset)勉強する"],
                    shortTitle: "勉強を始める", systemImageName: "timer")
    }
}
```

- フレーズには必ず `\(.applicationName)` を入れます（アプリ名のないフレーズは登録できません）。**「勉強を始める」だけで Siri を呼ぶことはできず、「StudyReel で勉強を始める」になります**。
- 日本語のフレーズは、`AppShortcuts.xcstrings`（または `ja.lproj/AppShortcuts.strings`）に書きます。
- 1つのアプリで App Shortcuts は最大 10 個です。
- パラメーターに使う AppEnum の値（25分など）は、フレーズの中で使えるように `caseDisplayRepresentations` の日本語を用意します。
- ショートカットアプリ、Spotlight、Siri から使えます。**アクションボタン**（iPhone 15 Pro 以降）にも、ショートカットかコントロールとして割り当てられます。

**(C) コントロールセンター・ロック画面のコントロール（iOS 18、`ControlWidget`）**

- `StudyReelWidget/StudyStartControl.swift` を新しく作り、`ControlWidgetButton(action: StartStudyIntent(preset: .min25))` を置きます。`StudyReelWidgetBundle.swift:13` の body に足します。
- 同じコントロールが、コントロールセンター、ロック画面の下の2つのボタン、アクションボタンの3か所で使えます（WWDC24「Extend your app's controls across the system」）。
- **注意点：コントロールで使う Intent の型は、ウィジェット拡張から見える必要があります。**一方、アプリを開いて `perform` をアプリの中で動かすには、アプリのターゲットにも入っている必要があります。
  - そのため、**`StartStudyIntent` と `StudyPreset` のファイルは両方のターゲットに入れます**。
  - この repo はフォルダ同期なので、たとえば `Shared/` フォルダを作り、pbxproj で両方のターゲットにつなぐ必要があります。Xcode のない環境では、ここが一番間違えやすいところです。CI のビルドで確かめます。
- 代わりの方法として、ウィジェット拡張だけにある Intent から `OpenURLIntent(URL("studyreel://start?..."))` を返す方法もあります（iOS 18〜）。ただし、ドキュメントでは **universal link が前提**と書かれています。この app には Associated Domains がないので、カスタムスキームで動くかは保証されません。**おすすめしません**。
- `ControlWidgetToggle` で「勉強中かどうか」を表示する案もあります。ただし、止めるときにアプリを開かないと録画を正しく終えられないので、**ボタンだけにします**。状態を変えたら `ControlCenter.shared.reloadControls(ofKind:)` で更新します。

**(D) ロック画面のウィジェット**

- 今のウィジェットは `.systemSmall, .systemMedium` だけです（`StudyReelWidget.swift:287`）。
- `.accessoryCircular` と `.accessoryRectangular` を足し、`widgetURL(PomodoroData.launchURL(...))` を付けます。iOS 17 以降なら `Button(intent:)` も使えます。
- 勉強中は `Text(endTime, style: .timer)` を出します。

**(E) 集中モードのフィルター（`SetFocusFilterIntent`、iOS 16〜）**

できること：
- 集中モード（たとえば「勉強」）がオン／オフになったとき、システムが `perform()` を呼びます。そこで **App Group / UserDefaults の設定を変えられます**。
- 設定する値の例：
  - 「次に開いたらこのプリセットで始める」（ポモドーロ 50/10 など）
  - 「勉強仲間の通知を止める」（`BuddyProfile.notifies…` を一時的にオフ）
  - 「ホームに『勉強を始める』を大きく出す」
- `appContext`（`FocusFilterAppContext`）の `filterPredicate` / `notificationFilterPredicate` を返すと、システムがウィジェットや通知の出し方を変えます。

できないこと：
- **画面を出すこと、アプリを前面に出すこと、カメラや録画を始めること**はできません。Focus Filter の `perform` は裏で短く動くだけです。
- 「集中モードをオンにしたら自動で録画」はできません。代わりに「通知で『録画を始めますか？』と聞き、タップで開く」か、上の「次に開いたら」の方法にします。
- Focus Filter の Intent はアプリのターゲットに置きます。`perform` はアプリのプロセスで裏から呼ばれます。

**(F) Intent からカメラを開いてよいか**

- `openAppWhenRun` でアプリが**前面に出たあと**なら、`AVCaptureSession.startRunning()` は普通に使えます。今のウィジェットからの自動開始も同じ仕組みです。
- 裏（アプリを開かない Intent や `LiveActivityIntent`）からは、カメラは使えません。
  - 例外は、ビデオ通話アプリ向けの `isMultitaskingCameraAccessSupported` です。voip のビデオ会議アプリに限られるので、この app では使えません。
  - iOS 18 の `LockedCameraCapture`（ロック画面から開くカメラの拡張）は撮影アプリ向けです。拡張の中で閉じた仕組みなので、この app のタイマーや SwiftData とは合いません。おすすめしません。
- **審査について**：Siri やアクションボタンで、ポケットの中ですぐ録画が始まると、2.5.14（記録するときの明確な同意と表示）の点で心配があります。
  - Intent から始めたときは、**3秒のカウントダウンと「録画中」の大きな表示を出し、録画なしに切り替えられるようにします**。
  - 初回は「ショートカットからも録画を始めますか？」と確かめます。
  - 今のウィジェットからの自動開始にも、同じ配慮を入れるとよいです。

### 4-3. 変えるファイル

- 新規：`Shared/Intents/StartStudyIntent.swift`、`Shared/Intents/StudyPreset.swift`（両方のターゲット）
- 新規：`StudyTimerAndVideo/Intents/StudyReelShortcuts.swift`、`StudyTimerAndVideo/Intents/StudyFocusFilter.swift`
- 新規：`StudyReelWidget/StudyStartControl.swift`
- 変更：`StudyReelWidget/StudyReelWidgetBundle.swift`、`StudyReelWidget/StudyReelWidget.swift`（accessory ファミリー、`WidgetSessionDraft` の source）
- 変更：`Models/CurrentSessionDraft.swift`（`.shortcut`、ポモドーロの plan）、`Views/StartView.swift`（下書きを読むときの source とカウントダウン）、`ContentView.swift`（`badgeCaption`、`:551-558`）
- 変更：`project.pbxproj`（共有フォルダのメンバーシップ）、文言（`AppShortcuts.xcstrings`）

### 4-4. 審査のリスク

- 中くらいです。主に「同意なしに録画が始まる」という見え方の問題です。上のカウントダウンで下げられます。
- Focus Filter で「できないこと」（自動録画）を説明に書くと、却下の理由になりえます。

---

## 5. 1か月の Vlog

### 5-1. 今の1週間の Vlog

- `Utilities/WeeklyVlogMaker.swift`：
  - `clips(from:in:)`（`:91-97`）で、週の中の記録のうち動画があるものを日付順に並べます。1本の記録が1クリップです。
  - `allocate`（`:149-166`）で長さを配ります。全体の目標は `min(60, max(30, 本数 × 6))` 秒です。タイトルの 1.5 秒を引き、勉強時間の割合で配り、1本あたり最低 3 秒、元の動画より長くはしません。
  - `renderVideo`（`:170-275`）：1080×1920（または横長）、30fps、H.264、10Mbps の `AVAssetWriter` です。
    - 1枚の絵を `frames` 回書き込みます（`append`、`:208-232`）。
    - クリップごとに、30倍速より速いときは `AVAssetImageGenerator` で必要なコマだけ取り出します（`:296-318`）。遅いときは `AVAssetReader` で順に読みます（`:320-350`）。
    - `autoreleasepool` で1コマごとにメモリを放しています。
  - BGM は `BGMRenderer.render`（`Utilities/VideoEditing.swift:125-`）で長さに合わせてくり返し、`addMusic`（`:498-524`）で `AVAssetExportPresetHighestQuality` を使って**もう一度エンコード**しています。
- 画面は `Views/WeeklyVlogView.swift`（週の選択、向き、BGM、Pro の確認、ShareLink、写真への保存）です。
- 使う動画は「アプリ内に残した書き出し済みの動画」です（`MediaStore.storeVideo`、`VideoReviewView.swift:618-621`）。**モザイクありを優先して残しますが、「モザイクなし」で保存した人の動画はモザイクなしです**（`VideoReviewView.swift:15, 588-594`）。SNS に出すものなので、6章と同じ注意が必要です。

### 5-2. 1か月にするときの問題

- 30日ぶんを今の `allocate` に入れると、目標は 60 秒（上限）で、最低 3 秒 × 30 = 90 秒になり、収まりません。0.8 倍に縮めても 2.4 秒 × 30 = 72 秒で、60 秒を超えます。また、**1日に何本も撮る人はクリップがさらに増えます**。
- 1コマずつ `AVAssetImageGenerator` で取り出す処理（30倍速より速いとき）は、本数が多いと書き出しが遅くなります。1か月で 100 本を超えると数分かかります。

### 5-3. おすすめのやり方

- **日ごとにまとめます。**`clips(from:in: DateInterval)` を一般化し、同じ日の記録は「いちばん長い記録の動画」を使うか、その日の動画を順につなぎます。ラベルはその日の合計時間にします。
- **長さの配り方を、期間の長さで変えます。**
  - 例：1か月なら目標 60〜75 秒。1日 1.5〜3 秒、勉強時間の多い日を長くします。
  - 日数 × 最低秒数が目標を超えるときは、**最低秒数を下げます**（1.2 秒まで）。それでも超えるときは、**勉強時間の上位の日を選びます**（ほかの日は、最後に「この月の毎日」として 0.3 秒ずつの早送りでまとめる）。
  - Instagram リールや TikTok は 60 秒を超えても投稿できますが、**多くの SNS で扱いやすい 60 秒前後**にしておくのが無難です。
- タイトルに月と合計時間を入れます。最後に3章のヒートマップを 1.5 秒の締めとして入れると、月の Vlog らしくなります（`ImageRenderer` の絵を CIImage にして `append` するだけです）。
- **メモリ：**今の作りは1コマずつ処理しているので、本数が増えても**メモリはほとんど増えません**。気をつけるのは**時間**と**一時ファイルの容量**です。
  - 一時ファイル：10Mbps × 75 秒 ≒ 94MB に、BGM を足してもう一度書き出したぶんが加わります。
  - 書き出し中に裏に回ると止まる可能性があるので、`UIApplication.beginBackgroundTask` を付けておきます。
  - `addMusic` の再エンコードはやめて、`AVAssetWriter` に音声トラックを直接書き込むと、時間と画質のロスが減ります（`VideoExporter` の BGM はすでにこの書き方です。`VideoExporter.swift:114-170`）。
- 型の名前は `WeeklyVlogWeek` から `VlogPeriod`（thisWeek / lastWeek / thisMonth / lastMonth）に広げます。`SharePeriod`（`StudyShareView.swift:349-380`）も同じ期間を使っているので、合わせます。

### 5-4. 変えるファイル

`Utilities/WeeklyVlogMaker.swift`（名前を `VlogMaker` にするかは任意。`allocate`、日ごとにまとめる処理、締めのカード、音声の書き込み）、`Views/WeeklyVlogView.swift`（期間の選択、進み具合、時間の目安）、`Views/StartView.swift:278`（入口の文言）、`Views/StudyShareView.swift`（「Vlog を共有」の期間）、テスト（`allocate` は純粋な関数なので、すぐテストを書けます）。

### 5-5. リスク

技術的には中くらいです（書き出し時間）。審査は低いです。Pro にするなら `WeeklyVlogView` の今の BGM の Pro の確認（`:144-148`）に合わせます。

---

## 6. 勉強仲間に 10 秒のモザイク動画を送る（CloudKit）

### 6-1. 今の「今日の1コマ」の仕組み

- 選ぶ：`Views/Buddies/BuddyPhotoViews.swift:214-233`。動画のある記録（直近、最大20件）から選び、スライダーで位置を決めます。
- 取り出す：`BuddyPhotos.frame(from:at:)`（`Utilities/Buddies/BuddyPhotos.swift:22-32`）で、**アプリ内に残した動画**から1コマを取り出します。
- モザイク：`BuddyPhotos.mosaicked`（`:36-57`）。**Vision で顔をその場で探し直し**（`hideRects`、`:60-76`：顔を広めにとり、顔がなければ上半身の上の方を隠す）、`CIPixellate` をかけます。元の動画にモザイクがあるかどうかに頼らず、**送る前にかならずかけ直しています**。
- 確かめる：`SCSensitivityAnalyzer` で、モザイクの前と後の両方を確かめます（`BuddyPhotoViews.swift:361-368`、`BuddyPhotos.swift:85-89`）。端末の設定がオフのときは判定できません。
- 送る：`BuddyCloud.sendPhoto`（`Utilities/Buddies/BuddyCloud.swift:713-741`）。
  - 次の条件をすべて確かめます：グループの `photosEnabled`（オーナーが決める。初めはオフ）、`BuddyProfile.photosOn`、1日1枚、締め出し（`checkPhotoBans`、`:694-706`：公開 DB の `ban-<id>`）。
  - JPEG を `CKAsset` にして、**グループのゾーン（オーナーの private DB のゾーンを CKShare で共有したもの。参加者からは shared DB）**に `BuddyPhoto` として保存します。
  - `expiresAt` は 24 時間後です。期限が過ぎたら `removeExpiredPhotos`（`:680-691`）で消します。
- 見る：`BuddyPhotos.data(for:in:)`（`:121-138`）。取ってきて Caches に置き、受け取った側でも `SCSensitivityAnalyzer` で確かめます。
- 通報：`BuddyCloud.report`（`:770-798`）。**公開 DB** の `BuddyReport` に、写真の `CKAsset` も入れて送ります。開発者がコンソールで見る手順は `docs/buddies-moderation.md` にあります。
- 年齢：iOS 26 の DeclaredAgeRange で 18 歳未満と分かったら、写真を初めからオフにします（`BuddyPhotos.swift:142-168`）。
- スキーマ：`docs/cloudkit/schema.ckdb:90-106`（BuddyPhoto）、`:166-186`（BuddyReport）。

### 6-2. 保存先と容量

- **グループの中身は共有ゾーンなので、オーナーの iCloud の容量を使います**（private DB はそのユーザーの iCloud 容量に数えられます。参加者が書いたレコードも、オーナーのゾーンにあればオーナーの容量です）。
  - 10 秒の動画をたとえば 1.5MB 以下にして、1人1日1本、24 時間で消すなら、6人のグループでも最大 10MB ほどです。オーナーの iCloud が満杯なら `CKError.quotaExceeded` になるので、メッセージを出します（今の `describe` に足します）。
- **CKAsset の大きさの上限**：Apple のエンジニアがフォーラムで「1つの CKAsset は、ユーザーの iCloud に空きがあれば 50GB まで」と答えています（公式ドキュメントではなく、フォーラムの回答です）。50MB という数字は古い CloudKit Web Services の話です。10 秒の動画なら問題になりません。
- **公開 DB は開発者の容量**です（ユーザーが増えると無料の枠も増えます）。通報に動画を付けると公開 DB を使うので、**通報の動画は送ったものと同じ小さいファイル（1.5MB 以下）にし、対応が終わったら消す**（今の手順の 90 日）ようにします。
- レコード本体（Asset を除く）は 1MB までです。メタデータだけなので問題ありません。

### 6-3. 「モザイクのない動画を絶対に送らない」ための作り

**大事な事実**

- アプリ内に残る動画は**モザイクなしの場合があります**（保存のときに「モザイクなし」を選んだ場合、`VideoReviewView.swift:15, 589-594`。場面ごとにモザイクを外すこともできます。`:328-331`）。
- 録画のときの顔の位置（`FaceTrack`）は、保存すると**素の動画と一緒に捨てられます**（`VideoReviewView.swift:636-643` で `result.url` を消し、track は残しません）。

**おすすめ**

1. **送る動画は専用の書き出しで作ります**（`Utilities/Buddies/BuddyClips.swift`、新規）。
   - 入力：アプリ内の動画と、開始位置（10 秒）。
   - 1コマごとに `VNDetectFaceRectanglesRequest` と `VNDetectHumanRectanglesRequest` で顔を探し直し、今の `BuddyPhotos.hideRects` の考え方で隠します。
   - **見つからなかったコマは、前後で見つかった枠を広げて使います。どのコマでも見つからないときは、画面の上半分を隠すか、送らせません。**つまり、顔が見つからないときは隠す側に倒します。
   - 動画からは数コマおきに Vision をかけ、その間はなめらかにつなぎます（`FaceTracker` の 0.2 秒おきと同じ考え方です）。全部録画の動画は 30fps → 10 秒で 300 コマ、タイムラプスは書き出しで 30fps なので同じ 300 コマです。0.2 秒おきに Vision をかければ 50 回で、端末の上で数秒で終わります。
   - モザイクのマス目は今の写真と同じ `max(w, h) / 28` にします。**`CIPixellate` だけでなく、ぼかしを重ねる**と、動画のコマを重ねて元の顔を戻されにくくなります。
2. **型で守ります。**`BuddyCloud.sendClip(_ clip: MosaickedClip, …)` の引数は `BuddyClips` の中でしか作れない型にします（`fileprivate init`）。URL を直接受け取る関数は作りません。
3. **送る前の確かめ**：
   - `SCSensitivityAnalyzer.videoAnalysis(forFileAt:)` → `hasSensitiveContent()`（iOS 17〜）で、モザイク後の動画を確かめます。端末の設定がオフなら判定できないのは写真と同じです。
   - 送る前に、モザイクをかけた動画を**本人に必ず再生して見せ**、「送る」を押してもらいます。
4. **エンコード**：`AVAssetWriter` で `AVVideoCodecType.hevc`。
   - 縦 540×960 か 720×1280、`AVVideoAverageBitRateKey` 1_000_000〜1_200_000、`AVVideoMaxKeyFrameIntervalKey` 30、音声なし、`.mp4`。
   - **10 秒で約 1.2〜1.5MB** です。iOS 18 が動く端末はすべて HEVC のハードウェアエンコードに対応しています。
   - 受け取る側は `AVPlayer` で再生できます。
   - 透かし「StudyReel」を入れておくと、外に出回ったときに出どころが分かります。
5. 受け取る側でも `SCSensitivityAnalyzer` で確かめ、Caches に 24 時間だけ置きます（写真と同じです）。
6. **1日1本、24 時間で消す、グループのオーナーがオンにしたときだけ、18 歳未満は初めオフ、締め出し、ブロック**は、写真のしくみ（`photosEnabled`、`photosOn`、`checkPhotoBans`、`bannedSenders`、`block`）をそのまま使います。
   - レコードの型は `BuddyClip` を新しく作るか、`BuddyPhoto` に `video ASSET` と `kind` を足します。
   - **スキーマを変えたら、Production に反映し**（`docs/buddies-setup.md`）、`docs/cloudkit/schema.ckdb` も直します。
7. **通報**：`BuddyReportReason` に `.clip` を足すか、`.photo` の説明を「写真・動画」にします。`report(...)` に `clipData` を足し、`BuddyReport` に `clip ASSET` を足します。`docs/buddies-moderation.md` の手順に「動画」を書き足します。

### 6-4. 変えるファイル

`Utilities/Buddies/BuddyClips.swift`（新規）、`Utilities/Buddies/BuddyCloud.swift`（送る・消す・期限・通報・`loadGroup` の `listKeys` に追加）、`Utilities/Buddies/BuddyPhotos.swift`（`hideRects` を共通にする）、`Views/Buddies/BuddyPhotoViews.swift`（選ぶ・確認・再生）、`Views/Buddies/BuddyGroupView.swift`（表示）、`docs/cloudkit/schema.ckdb`、`docs/buddies-moderation.md`、プライバシーポリシー（動画を扱うと書く）、App Store Connect のプライバシーの回答（「写真または動画」）。

### 6-5. 審査のリスク

**中〜高です。**

- ガイドライン 1.2（ユーザーが作ったコンテンツ）で求められるのは、次の4つです。今の写真で**すでにあります**。
  - 不適切なものを止める仕組み
  - 通報と、すばやい対応
  - ブロック
  - 連絡先
- 動画にすると、**審査の担当者が実際に動画を送って確かめる**ことがあります。デモ用のグループと、モザイクのかかった見本を用意しておきます。
- 利用者に未成年が多いアプリなので、1.2.1(a)（年齢に合わない内容を見分け、年齢で制限する）や 5.1.4（子どもの個人情報）の点からも、**「初めはオフ」「グループのオーナーが許したときだけ」「24 時間で消える」**を説明に書いておきます。
- 顔が隠しきれていない動画が1本でも出回ると、信頼を大きく失います。上の「見つからないときは隠す側に倒す」と「送る前に本人が確認」は必ず入れます。

---

## 7. 勉強中の環境音（雨・カフェ・ホワイトノイズ）

### 7-1. 今の状態（ほとんどできています）

- `StudySound`（`Utilities/StudyMusicPlayer.swift:5-57`）：なし・雨の音（Rain.m4a）・集中ノイズ（BrownNoise.m4a）・BGM 4曲です。BGM の Pro と無料の区別は動画の BGM と同じです。
- `StudyMusicPlayer`（同 `:59-99`）：
  - `AVAudioSession` を `.playback` と `.mixWithOthers` にして、ほかのアプリの音楽を止めません（`:73`）。
  - `AVAudioPlayer` で `numberOfLoops = -1`、音量 0.6 でくり返します。
  - 一時停止中と裏にいる間は `hold(true)` で止め（`ContentView.swift:663, 743`）、終わったら `setActive(false, .notifyOthersOnDeactivation)` にします。
- 録画画面のメニュー（`ContentView.swift:383-427`）と、案内の文「動画には入りません」（`:372`）があります。
- **録音されない理由**：`AVCaptureSession` にマイク入力がなく（`TimeLapseRecorder.swift:94-129`）、`AVAssetWriter` も映像だけです（`:321-367`）。そのため、流した環境音が動画に入ることは**ありません**。
  - `automaticallyConfiguresApplicationAudioSession` は、マイク入力がないので関係しません（このプロパティは、音声の入力があるときにオーディオセッションを録音向けに変えるものです）。
  - 動画の BGM は、書き出すときに別のファイルから入れています（`VideoExporter.swift:97-170`）。
- 音のファイル：`StudyTimerAndVideo/Resources/BGM/`。Rain.m4a は 1.22MB、BrownNoise.m4a は 1.21MB（60 秒のループ）、BGM 4曲は 0.8〜1.15MB です。
  - **すべて `tools/bgm/ambient.py` と `songs.py` で作った自作の音**で、他人の録音は使っていません（`tools/bgm/README.md`）。

### 7-2. 足すこと

1. **カフェの音とホワイトノイズ**
   - ホワイトノイズとピンクノイズは `ambient.py` に関数を足すだけです（ブラウンノイズと同じ作り方）。
   - **カフェの音は合成では作りにくいです**（話し声のざわめき、食器の音）。次の2つの方法があります。
     - (a) 合成で近づける：帯域を絞った多人数の「ざわめき」と、ランダムなカップの音を作ります。
     - (b) **CC0（著作権を放棄したもの）の録音を使い、出どころと許諾を `tools/bgm/README.md` に記録します**。repo の方針（自作だけ）から外れるので、決めてから進めます。CC-BY などのクレジット表記が必要なものは、アプリ内の表示と動画への使い道が面倒になるので避けます。
   - 容量：60 秒のステレオ AAC で約 1.2MB です。**ノイズはモノラル・96kbps でも聞いて分からない**ので、0.7MB 程度にできます。3つ足しても +3MB ほどです。ループの長さは 60 秒で十分です（それより短いと、くり返しが耳につきます）。
2. **音量のつまみ**：今は 0.6 で固定です（`StudyMusicPlayer.swift:77` 付近）。`AVAudioPlayer.volume` を設定で変えられるようにします。
3. **2つの音を重ねる**（雨 + BGM など）：`AVAudioPlayer` を2つ使えば重ねられます。これから音を増やすなら、`AVAudioEngine` と `AVAudioPlayerNode` にしておくと、フェードやつなぎ目が扱いやすくなります。
4. **画面ロック中・裏でも流す（任意）**
   - `UIBackgroundModes` に `audio` を足します。`ContentView.handleScenePhase` の `.background` で `music.hold(true)` にしている部分（`:743`）を設定で変えられるようにします。
   - **審査**：実際に音を流しているならバックグラウンドの audio は正しい使い方です（2.5.4）。ただし、**音を流していないときにアプリを動かし続ける目的で使うと、却下されます**。録画はどちらにしても裏では止まるので、審査の説明に「環境音を流し続けるため」と書きます。
   - 付けると、ポモドーロの Live Activity を区切りで更新できるという副作用があります（1章）。
   - 電話や Siri で止まったとき：`AVAudioSession.interruptionNotification` を受けて、終わったら `.shouldResume` で再開します（今はありません）。
   - ロック画面の「再生中」の表示（`MPNowPlayingInfoCenter`）は、`.mixWithOthers` のときは出ません。ほかのアプリの音楽と重ねる設計のままなら、それで構いません。
5. **将来マイクを使う場合（全部録画に音声を足すなど）の注意**：マイクを入れると、`AVCaptureSession` がオーディオセッションを録音向けに変えます（`automaticallyConfiguresApplicationAudioSession` が既定で true）。**流している環境音がスピーカーから出てマイクに入ります**。その場合は、イヤホンのときだけにするか、音声入力は使わない方針にします。今は入らないので問題ありません。

### 7-3. 変えるファイル

`Utilities/StudyMusicPlayer.swift`、`ContentView.swift`（メニュー・裏に回ったとき）、`Views/SettingsView.swift`（音量・裏でも流す）、`StudyTimerAndVideo/Info.plist`（`audio`、任意）、`tools/bgm/ambient.py`、`Resources/BGM/*.m4a`、`tools/bgm/README.md`、文言。

### 7-4. リスク

低いです。カフェの音の出どころ（許諾）と、`audio` モードを付けるときの審査の説明が注意点です。

---

## 8. 長時間録画の電池・発熱・空き容量（今は何もしていません）

### 8-1. 今の状態

- `ProcessInfo.thermalState`、`thermalStateDidChangeNotification`、`AVCaptureDevice.systemPressureState`、`isLowPowerModeEnabled`、空き容量の確認は、**どこにもありません**。
- 全部録画のときだけ、「1時間で約2GB使います」の注意を出しています（`ContentView.swift:532-537`）。
- カメラは `.high` プリセット・既定のフレームレート（30fps）で**ずっと動いています**（`TimeLapseRecorder.swift:102`）。タイムラプスは5秒に1枚しか使わないのに、毎秒30コマを受け取っています。
- 顔の検出は 0.2 秒おきです（`FaceTracker.swift:29-33`）。
- 画面を暗くする機能（`setDimmed`、`ContentView.swift:767-778`）と、スリープしない設定（`isIdleTimerDisabled = true`、`:626`）はあります。
- **ディスクがいっぱいで書き込みに失敗したとき**：`append` は false を返すだけです（`TimeLapseRecorder.swift:305-316`）。`finish` は `writer.status == .writing` でなければ `discardWriter()` を呼び、**ファイルを消します**（`:208-212, 243-254`）。`movieFragmentInterval = 10 秒`（`:352`）で途中まで再生できるファイルになっているのに、**失敗したときは全部なくなります**。

### 8-2. おすすめ

1. **タイムラプスのときはフレームレートを下げます**：`device.activeVideoMinFrameDuration = CMTime(1, 10)`（10fps）や 5fps にします。CPU とカメラの消費電力がはっきり減ります。全部録画は 30fps のままにします。
2. **熱**：`thermalStateDidChangeNotification` と `systemPressureState` の KVO を見ます。
   - `.serious` になったら、フレームレートを 5fps に下げ、`sessionPreset` を `.hd1280x720` に下げ、画面を暗くするよう案内します。
   - `.critical` になったら、**録画だけ止めて勉強時間は数え続け**、「端末が熱くなったので録画を止めました」と出します。今の `stopRecordingWhileAway` と同じ扱いにできます。
   - `systemPressureState.level == .shutdown` のときは、カメラがすぐ止まります。
3. **電池**：
   - `UIDevice.current.isBatteryMonitoringEnabled = true` にし、20% 以下で充電していなければ、充電をすすめます。
   - `isLowPowerModeEnabled` なら、初めからタイムラプスの設定を軽くします。
4. **空き容量**：
   - 始める前に `URLResourceValues.volumeAvailableCapacityForImportantUsage` を見ます。全部録画なら「予定時間 × 2GB/時」、タイムラプスなら数百 MB が目安です。足りなければ、注意を出すか、タイムラプスをすすめます。
   - 録画中も1分おきに確かめ、残りが 500MB を切ったら止めて保存します。
   - 書き込みに失敗したとき（`writer.status == .failed`）は、ファイルを消さずに、**最後の区切りまでを確認画面に渡します**（`SessionRecovery` の控えと同じ考え方です）。
5. 確認画面の書き出し（`VideoExporter`）と Vlog の書き出しも、一時ファイルを作る前に容量を確かめます。

### 8-3. 変えるファイル

`Utilities/TimeLapseRecorder.swift`（フレームレート、熱、書き込み失敗）、`ContentView.swift`（表示と止め方）、`Utilities/RecordingSettings.swift`（目安の計算）、`Utilities/VideoExporter.swift`、`Utilities/WeeklyVlogMaker.swift`。

---

## 9. おすすめの作る順番

| 順 | 機能 | 理由 |
| --- | --- | --- |
| 1 | **8 の電池・発熱・空き容量**（とくにタイムラプスのフレームレートと、書き込み失敗で消える問題） | 小さい変更で、今の利用者にすぐ効きます。ポモドーロで長く録画するようになる前に入れておくべきです |
| 2 | **2 のカメラを使わないセッション** | データ側はもう対応しています。変えるのはプレビューを作らないことと入口だけです |
| 3 | **3 のヒートマップと共有カード** | 独立していて、リスクが低いです。`ImageRenderer` の仕組みがすでにあります |
| 4 | **1 のポモドーロ** | 録画の一時停止はもう集中時間だけを数えます。新しく作るのは時刻から計算する仕組み、通知、Live Activity の ContentState です。2 と 8 の後に作ると、休憩中のカメラ停止なども作りやすくなります |
| 5 | **4 の App Intents・ショートカット・コントロール** | ポモドーロのプリセットを Intent の引数にできるので、1 の後が効率的です。ターゲットの共有（pbxproj）は CI で確かめます |
| 6 | **7 の環境音を増やす・裏でも流す** | ほとんどできています。カフェの音の出どころを決めたら、すぐ足せます。`audio` モードを付けると 1 の Live Activity の更新にも役立ちます |
| 7 | **5 の1か月の Vlog** | `allocate` と日ごとにまとめる処理が中心で、中くらいの量です。3 の締めのカードを使えます |
| 8 | **6 の 10 秒のモザイク動画** | 審査と安全のリスクがいちばん高く、スキーマの変更、通報の手順、プライバシーポリシーの更新も必要です。最後にじっくり作ります |

---

## 参考（確かめた資料）

- LiveActivityIntent（iOS 17〜、アプリを開かずにプロセスを起こして実行）：https://developer.apple.com/documentation/appintents/liveactivityintent
- SetFocusFilterIntent（iOS 16〜、appContext）：https://developer.apple.com/documentation/appintents/setfocusfilterintent
- OpenIntent（iOS 16〜、アプリを前面に出す）：https://developer.apple.com/documentation/appintents/openintent
- AppIntent.supportedModes（iOS 26〜）：https://developer.apple.com/documentation/appintents/appintent/supportedmodes
- OpenURLIntent（iOS 18〜、universal link 前提）：https://developer.apple.com/documentation/appintents/openurlintent
- WWDC24「Extend your app's controls across the system」（コントロール。iOS 18。コントロールセンター・ロック画面・アクションボタン）：https://developer.apple.com/videos/play/wwdc2024/10157/
- WWDC22「Meet Focus filters」：https://developer.apple.com/videos/play/wwdc2022/10121
- Live Activity の長さ（8時間 + ロック画面に最大4時間）：https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities ／ https://developer.apple.com/forums/thread/797676
- AlarmKit（iOS 26）：https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit
- AVCaptureSession.automaticallyConfiguresApplicationAudioSession：https://developer.apple.com/documentation/avfoundation/avcapturesession/automaticallyconfiguresapplicationaudiosession
- マルチタスク中のカメラ（ビデオ会議アプリ向け）：https://developer.apple.com/documentation/avfoundation/avcapturesession/ismultitaskingcameraaccessenabled ／ https://developer.apple.com/forums/thread/710193
- SCSensitivityAnalyzer（iOS 17〜、videoAnalysis(forFileAt:)）：https://developer.apple.com/documentation/sensitivecontentanalysis/scsensitivityanalyzer
- CKAsset の大きさ（フォーラム、Apple のエンジニアの回答で 50GB）：https://developer.apple.com/forums/thread/827897
- App Review Guidelines（1.2、2.5.4、2.5.14、5.1.1、5.1.4）：https://developer.apple.com/app-store/review/guidelines/

注：ControlWidget の API の細かい名前（`ControlWidgetButton` など）と、App Shortcuts の上限（10個）は、記憶と WWDC のセッションをもとに書いています。developer.apple.com のページは取得できなかったので、作るときに Xcode 26 の SDK で確かめてください。
