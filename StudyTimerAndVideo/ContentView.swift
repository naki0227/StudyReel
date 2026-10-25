import SwiftUI
import SwiftData
import UIKit
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var storeKit: StoreKitManager
    @AppStorage(OverlayFont.storageKey) private var overlayFontRaw = OverlayFont.defaultFont.rawValue
    @AppStorage(CaptureOrientation.storageKey) private var captureOrientationRaw = CaptureOrientation.landscape.rawValue
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]

    @StateObject private var recorder = TimeLapseRecorder()
    @StateObject private var timerModel = TimerViewModel()
    @StateObject private var stopwatchModel = StopwatchViewModel()
    @StateObject private var music = StudyMusicPlayer()
    @AppStorage(StudySound.storageKey) private var studySoundRaw = StudySound.none.rawValue

    @State private var isRecording = false
    @State private var showSaveAlert = false
    @State private var recordingMode: RecordingMode = .timelapse
    @State private var videoSaved = false
    @State private var showPaywall = false
    @State private var reviewResult: RecordingResult?
    @State private var reviewOutcome: Bool?
    @State private var pendingMedia = SessionMedia()
    @State private var showSaveSheet = false
    @State private var showDiscardAlert = false
    @State private var pendingDuration = 0
    @State private var isPaused = false
    @State private var didAutoStart = false
    @State private var sessionStartedAt: Date?
    // アプリを離れたり電話が来たりして、録画だけ止まっている
    @State private var stoppedWhileAway = false
    @State private var showResumeCard = false
    @State private var isDimmed = false
    @State private var brightnessBeforeDim: CGFloat?
    @State private var tickCount = 0
    @AppStorage(CoachTour.recordingKey) private var hasSeenRecordingTour = false
    @State private var showRecordingTour = false
    @State private var lowStorageBeforeStart = false
    // ポモドーロ。終わった集中の回数・いまの集中が始まったときの勉強時間・休憩が終わる時刻
    @AppStorage(PomodoroPlan.storageKey) private var pomodoroRaw = PomodoroPlan.off.rawValue
    @State private var focusRound = 0
    @State private var focusStartElapsed = 0
    @State private var breakEndsAt: Date?
    // ウィジェット・Siri から開いたとき、撮影が始まる前の3秒（知らないうちに撮られないように）
    @State private var startCountdown: Int?

    var subjectManager: SubjectManager
    var totalSeconds: Int
    var onFinish: () -> Void
    var mode: Mode
    var bootstrap: SessionBootstrap?

    init(
        subjectManager: SubjectManager,
        totalSeconds: Int,
        onFinish: @escaping () -> Void,
        mode: Mode,
        bootstrap: SessionBootstrap? = nil
    ) {
        self.subjectManager = subjectManager
        self.totalSeconds = totalSeconds
        self.onFinish = onFinish
        self.mode = mode
        self.bootstrap = bootstrap
        let savedMode = RecordingMode(rawValue: UserDefaults.standard.string(forKey: RecordingMode.storageKey) ?? "") ?? .timelapse
        _recordingMode = State(initialValue: (bootstrap?.initialRecordingEnabled ?? true) ? savedMode : .off)
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                if recordingMode == .off {
                    // 録画なしはカメラを起こさない（緑のランプも電池も使わない）
                    NoCameraBackground()
                } else if DemoMode.isActive {
                    DemoCameraView()
                } else {
                    CameraPreview(recorder: recorder, isLandscape: geometry.size.width > geometry.size.height)
                }
            }
            .ignoresSafeArea()

            // 文字やボタンが読めるよう、上下だけごく薄く落とす。映像はほぼそのまま見せる
            VStack(spacing: 0) {
                LinearGradient(colors: [Color.black.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 130)
                Spacer()
                LinearGradient(colors: [.clear, Color.black.opacity(0.32)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 170)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height {
                    landscapeControls
                } else {
                    portraitControls
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            if showResumeCard {
                resumeCard
                    .transition(.opacity)
            }

            if let breakEndsAt {
                breakCard(endsAt: breakEndsAt)
                    .transition(.opacity)
            }

            if let startCountdown {
                countdownCard(startCountdown)
                    .transition(.opacity)
            }

            if isDimmed {
                dimmedView
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: isDimmed)
        .animation(.easeOut(duration: 0.25), value: showResumeCard)
        .animation(.easeOut(duration: 0.25), value: breakEndsAt)
        .coachTour(recordingTourSteps, isPresented: $showRecordingTour) {
            hasSeenRecordingTour = true
        }
        .alert(videoSaved ? L10n.string("保存完了") : L10n.string("動画を保存できませんでした"), isPresented: $showSaveAlert) {
            Button(L10n.string("OK")) {
                showSaveSheet = true
            }
        } message: {
            Text(saveResultMessage)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onChange(of: recordingMode) { _, newMode in
            if newMode.isPro && !storeKit.isProUnlocked {
                recordingMode = .timelapse
                showPaywall = true
            } else if newMode != .off {
                UserDefaults.standard.set(newMode.rawValue, forKey: RecordingMode.storageKey)
            } else {
                recorder.stopSession()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
        .onChange(of: recorder.isInterrupted) { _, interrupted in
            if interrupted {
                stopRecordingWhileAway()
            } else if stoppedWhileAway && scenePhase == .active {
                showResumeCard = true
            }
        }
        .onOpenURL { url in
            // ロック画面・Dynamic Island の停止ボタン
            if url.scheme == "studyreel", url.host == "stop", isRecording {
                stopAndSave()
            }
        }
        .fullScreenCover(item: $reviewResult, onDismiss: {
            if let reviewOutcome {
                videoSaved = reviewOutcome
                showSaveAlert = true
            } else {
                showSaveSheet = true
            }
            reviewOutcome = nil
        }) { result in
            VideoReviewView(result: result) { outcome, media in
                reviewOutcome = outcome
                pendingMedia = media
                reviewResult = nil
            }
        }
        .alert(L10n.string("記録を中断しますか？"), isPresented: $showDiscardAlert) {
            Button(L10n.string("戻る"), role: .cancel) {}
            Button(L10n.string("中断する"), role: .destructive) {
                discardSession()
            }
        } message: {
            Text(L10n.string("ここまでの記録は保存されません。"))
        }
        .sheet(isPresented: $showSaveSheet, onDismiss: { finishSession() }) {
            SessionSaveView(subjectManager: subjectManager, duration: pendingDuration, media: pendingMedia, materialID: bootstrap?.materialID)
        }
        .onChange(of: captureOrientationRaw) {
            OrientationLock.lock(captureOrientation.mask)
        }
        .onAppear {
            lowStorageBeforeStart = !DemoMode.isActive && !TimeLapseRecorder.hasEnoughStorage
            OrientationLock.lock(captureOrientation.mask)
            // Pro が切れていたら、覚えていた撮り方をタイムラプスに戻す
            if recordingMode.isPro && !storeKit.isProUnlocked {
                recordingMode = .timelapse
            }
            if !hasSeenRecordingTour && bootstrap?.autoStart != true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if !isRecording { showRecordingTour = true }
                }
            }
            guard bootstrap?.autoStart == true, !didAutoStart else { return }
            didAutoStart = true
            if isRecordingVideo && bootstrap?.source != .app {
                startCountdown = 3
            } else {
                startRecording()
            }
        }
        .onDisappear {
            music.stop()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            syncWithWidgetStopState()
            saveRecoveryIfNeeded()
            checkPomodoro()
            tickStartCountdown()
        }
    }

    // MARK: - 録画画面のレイアウト
    // 中央はカメラ映像のために空けて、操作は端に寄せる。横向きは右側、縦向きは下側にシャッター

    private var landscapeControls: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                topLeftButtons
                Spacer()
                if !isRecording {
                    modeChips
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                timerBadge
                Spacer()
                VStack(spacing: 16) {
                    if isRecording {
                        dimButton
                    }
                    shutterButton
                    if isRecording && !isOnBreak {
                        pauseButton
                    }
                }
                .frame(width: 76)
                Spacer()
                if recordingMode == .full && !isRecording {
                    storageNote
                }
            }
        }
    }

    private var portraitControls: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                topLeftButtons
                Spacer()
                timerBadge
            }
            Spacer()
            VStack(spacing: 14) {
                if !isRecording {
                    modeChips
                    if recordingMode == .full {
                        storageNote
                    }
                }
                ZStack {
                    shutterButton
                    if isRecording {
                        HStack {
                            if isOnBreak {
                                Color.clear.frame(width: 44, height: 44)
                            } else {
                                pauseButton
                            }
                            Spacer()
                            dimButton
                        }
                        .frame(width: 220)
                    }
                }
            }
        }
    }

    private var topLeftButtons: some View {
        HStack(spacing: 10) {
            Button {
                showDiscardAlert = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.22)))
            }
            .accessibilityLabel(L10n.string("中断"))

            musicButton

            if !isRecording {
                pomodoroButton
            }

            if !isRecording {
                Button {
                    captureOrientationRaw = captureOrientation.toggled.rawValue
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "rotate.right")
                        Text(captureOrientation.toggled.title)
                    }
                    .font(ReelTheme.sans(13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Capsule().fill(Color.white.opacity(0.22)))
                }
                .coachMark("rec.orientation")
                .accessibilityLabel(L10n.format("%@に切り替える", captureOrientation.toggled.title))
            }

            if recordingMode != .off && !canRecord {
                Text(L10n.string("この端末では録画できません。"))
                    .font(ReelTheme.sans(11))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }

    // 右上のタイマー。動画に入る文字と同じフォントで、白い文字に影をつける
    private var timerBadge: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(displayedTime)
                    .font(OverlayFont.resolved(rawValue: overlayFontRaw, isPro: storeKit.isProUnlocked).font(size: 26))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Text("\(statusText) · \(badgeCaption)")
                .font(ReelTheme.sans(11))
                .opacity(0.85)
                .lineLimit(1)
            if let notice = recordingNotice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(ReelTheme.sans(11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.35)))
                    .padding(.top, 4)
            }
        }
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 1)
        .coachMark("rec.timer")
    }

    // カメラのシャッターのような丸いボタン。開始前は丸、録画中は四角
    private var shutterButton: some View {
        Button {
            if isRecording {
                stopAndSave()
            } else {
                startRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 72, height: 72)
                if isRecording {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                } else {
                    Circle()
                        .fill(isRecordingVideo ? Color(red: 1.0, green: 0.36, blue: 0.33) : Color.white)
                        .frame(width: 58, height: 58)
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 8)
        }
        .coachMark("rec.shutter")
        .accessibilityLabel(L10n.string(isRecording ? "終了して保存" : "開始"))
    }

    private var pauseButton: some View {
        Button {
            togglePause()
        } label: {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.22)))
        }
        .accessibilityLabel(L10n.string(isPaused ? "再開" : "一時停止"))
    }

    private var recordingTourSteps: [CoachStep] {
        [
            CoachStep(id: "rec.shutter", title: L10n.string("ここで開始"), message: L10n.string("押すとタイマーと撮影が始まります。もう一度押すと終了して、確認画面に進みます。")),
            CoachStep(id: "rec.mode", title: L10n.string("撮り方を選ぶ"), message: L10n.string("タイムラプスは数秒に1枚撮ってつなげます。全部録画（Pro）はずっと動画で残します。")),
            CoachStep(id: "rec.music", title: L10n.string("勉強中の音"), message: L10n.string("雨の音や集中ノイズ、BGMを流しながら勉強できます。動画には入りません。")),
            CoachStep(id: "rec.orientation", title: L10n.string("縦か横か"), message: L10n.string("縦向きはリール向け、横向きは机全体が入ります。")),
            CoachStep(id: "rec.timer", title: L10n.string("残り時間"), message: L10n.string("録画中は🌙ボタンで画面を暗くできます。録画は続いたままです。"))
        ]
    }

    private func tickStartCountdown() {
        guard let startCountdown else { return }
        if startCountdown <= 1 {
            self.startCountdown = nil
            startRecording()
        } else {
            self.startCountdown = startCountdown - 1
        }
    }

    private func countdownCard(_ count: Int) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Text("\(count)")
                    .font(ReelTheme.serif(72))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text(L10n.string("撮影が始まります"))
                    .font(ReelTheme.sans(15, weight: .medium))
                    .foregroundColor(.white)
                Button {
                    startCountdown = nil
                    recordingMode = .off
                    recorder.stopSession()
                    startRecording()
                } label: {
                    Text(L10n.string("撮らずに時間だけ記録"))
                        .font(ReelTheme.sans(14, weight: .medium))
                        .foregroundColor(ReelTheme.ink)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 42)
                        .background(Capsule().fill(Color.white))
                }
                Button {
                    startCountdown = nil
                    startRecording()
                } label: {
                    Text(L10n.string("すぐ始める"))
                        .font(ReelTheme.sans(13))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(minHeight: 36)
                }
            }
        }
    }

    private var pomodoro: PomodoroPlan {
        PomodoroPlan(rawValue: pomodoroRaw) ?? .off
    }

    private var isOnBreak: Bool {
        breakEndsAt != nil
    }

    // 集中と休憩のくり返しを選ぶ。休憩の間はタイマーも撮影も止まる
    private var pomodoroButton: some View {
        Menu {
            Picker(L10n.string("休憩"), selection: $pomodoroRaw) {
                ForEach(PomodoroPlan.allCases) { plan in
                    Text(plan.title).tag(plan.rawValue)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cup.and.saucer")
                if pomodoro != .off {
                    Text(pomodoro.shortTitle)
                        .monospacedDigit()
                }
            }
            .font(ReelTheme.sans(13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, pomodoro == .off ? 0 : 12)
            .frame(minWidth: 38, minHeight: 38)
            .background(Capsule().fill(Color.white.opacity(0.22)))
        }
        .accessibilityLabel(L10n.string("休憩"))
    }

    // 休憩中。スマホから離れるよう勧める（休憩中にスマホを触ると、そのあとの勉強がはかどらない。docs/research/science.md）
    private func breakCard(endsAt: Date) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Text(L10n.format("%d回目の集中、おつかれさまでした", focusRound))
                    .font(ReelTheme.sans(13))
                    .foregroundColor(ReelTheme.secondary)
                Text(L10n.string("休憩"))
                    .font(ReelTheme.serif(22))
                    .foregroundColor(ReelTheme.ink)
                Text(timerInterval: Date()...max(endsAt, Date()), countsDown: true)
                    .font(ReelTheme.serif(44))
                    .foregroundColor(ReelTheme.ink)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                Text(L10n.string("スマホから少し離れて、遠くを見たり水を飲んだりしましょう。休憩の間は撮影もタイマーも止まっています。"))
                    .font(ReelTheme.sans(13))
                    .foregroundColor(ReelTheme.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    endBreak()
                } label: {
                    Text(L10n.string("休憩をおわる"))
                        .font(ReelTheme.sans(15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Capsule().fill(ReelTheme.accentDeep))
                }
                Button {
                    stopAndSave()
                } label: {
                    Text(L10n.string("終了して保存"))
                        .font(ReelTheme.sans(14, weight: .medium))
                        .foregroundColor(ReelTheme.accentDeep)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(ReelTheme.background))
        }
    }

    private var savedSound: StudySound {
        let sound = StudySound(rawValue: studySoundRaw) ?? .none
        return sound.isPro && !storeKit.isProUnlocked ? .none : sound
    }

    // 勉強中に流す音を選ぶ。選んだらすぐ鳴らして、次の記録でも同じ音にする
    private var musicButton: some View {
        Menu {
            Picker(L10n.string("勉強中の音"), selection: Binding(
                get: { savedSound },
                set: { chooseSound($0) }
            )) {
                ForEach(StudySound.allCases) { sound in
                    Label(
                        sound.isPro && !storeKit.isProUnlocked ? "\(sound.title)  PRO" : sound.title,
                        systemImage: sound.systemImage
                    )
                    .tag(sound)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: savedSound == .none ? "music.note" : savedSound.systemImage)
                if savedSound != .none {
                    Text(savedSound.title)
                        .lineLimit(1)
                }
            }
            .font(ReelTheme.sans(13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, savedSound == .none ? 0 : 12)
            .frame(minWidth: 38, minHeight: 38)
            .background(Capsule().fill(Color.white.opacity(0.22)))
        }
        .coachMark("rec.music")
        .accessibilityLabel(L10n.string("勉強中の音"))
    }

    private func chooseSound(_ sound: StudySound) {
        if sound.isPro && !storeKit.isProUnlocked {
            showPaywall = true
            return
        }
        studySoundRaw = sound.rawValue
        if sound == .none {
            music.stop()
        } else {
            music.play(sound)
        }
    }

    private var dimButton: some View {
        Button {
            setDimmed(true)
        } label: {
            Image(systemName: "moon.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.22)))
        }
        .accessibilityLabel(L10n.string("画面を暗くする"))
    }

    // 録画はそのまま続けて、画面だけ暗くする。電池の減りと発熱を抑え、目の前に置いても気にならない
    private var dimmedView: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            VStack(spacing: 8) {
                Text(displayedTime)
                    .font(OverlayFont.resolved(rawValue: overlayFontRaw, isPro: storeKit.isProUnlocked).font(size: 34))
                    .monospacedDigit()
                Text(L10n.string("タップで戻る"))
                    .font(ReelTheme.sans(12))
            }
            .foregroundColor(.white.opacity(0.28))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            setDimmed(false)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    // アプリを離れていた間は撮れていないので、戻ってきたら知らせて続きを撮れるようにする
    private var resumeCard: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Text(L10n.string("録画が止まっていました"))
                    .font(ReelTheme.serif(22))
                    .foregroundColor(ReelTheme.ink)
                Text(L10n.string("アプリを離れていた間は撮れていません。勉強時間はそのまま数えています。"))
                    .font(ReelTheme.sans(13))
                    .foregroundColor(ReelTheme.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    resumeAfterAway()
                } label: {
                    Text(L10n.string("録画を再開"))
                        .font(ReelTheme.sans(15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Capsule().fill(ReelTheme.accentDeep))
                }
                Button {
                    showResumeCard = false
                    stoppedWhileAway = false
                    stopAndSave()
                } label: {
                    Text(L10n.string("終了して保存"))
                        .font(ReelTheme.sans(14, weight: .medium))
                        .foregroundColor(ReelTheme.accentDeep)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(ReelTheme.background))
        }
    }

    private var modeChips: some View {
        modeChipRow
            .coachMark("rec.mode")
    }

    private var modeChipRow: some View {
        HStack(spacing: 6) {
            ForEach(RecordingMode.allCases) { option in
                Button {
                    recordingMode = option
                } label: {
                    HStack(spacing: 4) {
                        Text(option.title)
                        if option.isPro && !storeKit.isProUnlocked {
                            Text("PRO")
                                .font(.system(size: 9, weight: .heavy))
                                .opacity(0.75)
                        }
                    }
                    .font(ReelTheme.sans(12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .foregroundColor(recordingMode == option ? ReelTheme.ink : .white)
                    .background(Capsule().fill(recordingMode == option ? Color.white : Color.white.opacity(0.22)))
                }
            }
        }
    }

    // 撮影を止めているわけ。開始前は空き容量だけ見る
    private var recordingNotice: String? {
        guard recordingMode != .off else { return nil }
        if isRecording { return recorder.notice?.message }
        return lowStorageBeforeStart ? L10n.string("空き容量が少ないので、途中で撮影が止まるかもしれません") : nil
    }

    private var storageNote: some View {
        Text(L10n.string("全部録画は1時間で約2GB使います。"))
            .font(ReelTheme.sans(11))
            .foregroundColor(.white.opacity(0.85))
            .shadow(color: .black.opacity(0.4), radius: 4)
    }

    private var statusColor: Color {
        if isOnBreak { return .cyan }
        if isPaused { return .orange }
        if isRecording { return isRecordingVideo ? .red : .green }
        return .white.opacity(0.7)
    }

    private var statusText: String {
        if isOnBreak { return L10n.string("休憩中") }
        if isPaused { return L10n.string("一時停止中") }
        if isRecording { return L10n.string(isRecordingVideo ? "録画中" : "計測中") }
        return L10n.string("開始前")
    }

    private var badgeCaption: String {
        var parts = [mode == .timer ? L10n.string("タイマー") : L10n.string("ストップウォッチ")]
        if pomodoro != .off { parts.append(pomodoro.shortTitle) }
        parts.append(recordingLabel)
        if bootstrap?.source == .widget {
            parts.append(L10n.string("Widgetから開始"))
        } else if bootstrap?.source == .shortcut {
            parts.append(L10n.string("ショートカットから開始"))
        }
        return parts.joined(separator: " · ")
    }

    private var displayedTime: String {
        formatTime(mode == .timer ? timerModel.remaining : stopwatchModel.elapsed)
    }

    private var saveResultMessage: String {
        if !RecordingSettings.savesToPhotos {
            return videoSaved ? L10n.string("動画をアプリ内に保存しました。") : L10n.string("動画を保存できませんでした。空き容量を確認してください。")
        }
        return videoSaved ? L10n.string("動画を写真に保存しました。") : L10n.string("設定アプリで写真への追加を許可してください。")
    }

    private var captureOrientation: CaptureOrientation {
        CaptureOrientation(rawValue: captureOrientationRaw) ?? .landscape
    }

    // デモ表示ではカメラがなくても録画しているように見せる
    private var canRecord: Bool {
        recorder.canCaptureVideo || DemoMode.isActive
    }

    private var isRecordingVideo: Bool {
        recordingMode != .off && canRecord
    }

    private var recordingLabel: String {
        if recordingMode != .off && !canRecord { return L10n.string("録画できません") }
        return recordingMode.title
    }

    private func startRecording() {
        let elapsedBeforeLaunch = bootstrap?.elapsedSecondsAtLaunch ?? 0
        let startedAt = bootstrap?.startedAt ?? Date()
        sessionStartedAt = startedAt

        Task {
            await StudyNotificationManager.shared.clearPendingQuietReminder()
        }

        if mode == .timer {
            let remaining = max(totalSeconds - elapsedBeforeLaunch, 0)
            timerModel.start(seconds: remaining) {
                stopAndSave()
            }
            syncWidgetTimerStateIfNeeded(remainingSeconds: remaining)
        } else {
            stopwatchModel.start(from: elapsedBeforeLaunch)
            clearWidgetTimerState()
        }

        if isRecordingVideo {
            recorder.start(
                mode: recordingMode,
                interval: RecordingSettings.interval,
                sessionStart: startedAt,
                elapsedOffset: elapsedBeforeLaunch,
                isLandscape: captureOrientation.isLandscape
            )
        }

        isRecording = true
        isPaused = false
        stoppedWhileAway = false
        focusRound = 0
        focusStartElapsed = elapsedBeforeLaunch
        breakEndsAt = nil
        scheduleFocusEnd()
        if music.sound != savedSound {
            music.play(savedSound)
        }
        music.hold(false)
        UIApplication.shared.isIdleTimerDisabled = true
        StudyLiveActivityController.shared.start(
            isTimer: mode == .timer,
            seconds: mode == .timer ? max(totalSeconds - elapsedBeforeLaunch, 0) : elapsedBeforeLaunch,
            isRecording: isRecordingVideo
        )
        saveRecoveryIfNeeded(force: true)
        // 勉強仲間に「いま勉強中」と見せる
        BuddyCloud.shared.studyStarted(at: startedAt, plannedSeconds: mode == .timer ? totalSeconds : nil)
    }

    private func togglePause() {
        if isPaused {
            resumeClock()
            isPaused = false
            music.hold(false)
            scheduleFocusEnd()
        } else {
            pauseClock()
            isPaused = true
            music.hold(true)
            StudyNotificationManager.shared.clearPomodoro()
        }
        updateLiveActivity()
    }

    private func pauseClock() {
        if mode == .timer {
            timerModel.pause()
        } else {
            stopwatchModel.pause()
        }
        if isRecordingVideo {
            recorder.pause()
        }
    }

    private func resumeClock() {
        if mode == .timer {
            timerModel.resume {
                stopAndSave()
            }
        } else {
            stopwatchModel.resume()
        }
        if isRecordingVideo && !stoppedWhileAway {
            recorder.resume()
        }
    }

    // MARK: - ポモドーロ

    // 1秒ごと。集中の時間が来たら休憩に、休憩の時間が来たら集中に戻す（アプリを離れていた分は戻ったときに追いつく）
    private func checkPomodoro() {
        guard isRecording, pomodoro != .off else { return }
        if let breakEndsAt {
            if Date() >= breakEndsAt { endBreak() }
        } else if !isPaused, currentElapsed - focusStartElapsed >= pomodoro.focusSeconds {
            startBreak()
        }
    }

    private func startBreak() {
        focusRound += 1
        let seconds = pomodoro.breakSeconds(after: focusRound)
        // 離れていた間に休憩になったときは、再開のカードは出さない（休憩のあとに撮影を戻す）
        showResumeCard = false
        stoppedWhileAway = false
        pauseClock()
        if !DemoMode.isActive && isRecordingVideo { recorder.stopSession() }
        setDimmed(false)
        breakEndsAt = Date().addingTimeInterval(TimeInterval(seconds))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task {
            await StudyNotificationManager.shared.schedulePomodoro(
                title: L10n.string("休憩おわり"),
                body: L10n.string("机に戻って、StudyReel を開くと撮影が続きます。"),
                after: seconds
            )
        }
        updateLiveActivity()
    }

    private func endBreak() {
        guard isOnBreak else { return }
        breakEndsAt = nil
        focusStartElapsed = currentElapsed
        if isRecordingVideo { recorder.wakeSession() }
        resumeClock()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if mode == .timer { syncWidgetTimerStateIfNeeded(remainingSeconds: timerModel.remaining) }
        scheduleFocusEnd()
        updateLiveActivity()
    }

    // 集中が終わる時刻に知らせる（画面を見ていなくても休憩に気づけるように）
    private func scheduleFocusEnd() {
        guard isRecording, pomodoro != .off, !isOnBreak else { return }
        let left = pomodoro.focusSeconds - (currentElapsed - focusStartElapsed)
        Task {
            await StudyNotificationManager.shared.schedulePomodoro(
                title: L10n.string("休憩の時間です"),
                body: L10n.string("集中おつかれさまでした。少しスマホから離れて休みましょう。"),
                after: left
            )
        }
    }

    private func stopAndSave() {
        let completedDuration = mode == .timer ? max(totalSeconds - timerModel.remaining, 0) : stopwatchModel.elapsed
        pendingDuration = completedDuration
        // 確認画面の途中でアプリが終わっても、勉強時間だけは残せるよう最後の時間で控えておく
        saveRecoveryIfNeeded(force: true, elapsed: completedDuration)

        if isRecordingVideo && DemoMode.isActive {
            recorder.cancel()
            if let result = DemoSeeder.recordingResult(sessionStart: sessionStartedAt ?? Date()) {
                reviewResult = result
            } else {
                showSaveSheet = true
            }
        } else if isRecordingVideo {
            recorder.finish { result in
                if let result {
                    reviewResult = result
                } else {
                    showSaveSheet = true
                }
            }
        } else {
            showSaveSheet = true
        }

        timerModel.stop()
        stopwatchModel.stop()
        isRecording = false
        isPaused = false
        breakEndsAt = nil
        StudyNotificationManager.shared.clearPomodoro()
        sessionStartedAt = nil
        showResumeCard = false
        stoppedWhileAway = false
        setDimmed(false)
        music.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        clearWidgetTimerState()
        StudyLiveActivityController.shared.end()
        BuddyCloud.shared.studyEnded()
    }

    private func discardSession() {
        UIApplication.shared.isIdleTimerDisabled = false
        timerModel.stop()
        stopwatchModel.stop()
        recorder.cancel()
        music.stop()
        isRecording = false
        isPaused = false
        breakEndsAt = nil
        StudyNotificationManager.shared.clearPomodoro()
        sessionStartedAt = nil
        setDimmed(false)
        clearWidgetTimerState()
        StudyLiveActivityController.shared.end()
        BuddyCloud.shared.studyEnded()
        finishSession()
    }

    // 録画画面を閉じるときだけ向きの固定を外す（確認画面を出している間は固定したまま）
    private func finishSession() {
        SessionRecovery.clearSession()
        OrientationLock.unlock()
        onFinish()
    }

    // MARK: - 中断と再開

    private var currentElapsed: Int {
        mode == .timer ? max(totalSeconds - timerModel.remaining, 0) : stopwatchModel.elapsed
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // 裏に回るとカメラは止まる。勉強時間は数え続けて、録画だけ止めておく
            stopRecordingWhileAway()
            setDimmed(false)
            music.hold(true)
        case .active:
            music.hold(isPaused || !isRecording)
            if stoppedWhileAway && isRecording && !recorder.isInterrupted {
                showResumeCard = true
            }
        default:
            break
        }
    }

    private func stopRecordingWhileAway() {
        guard isRecording, isRecordingVideo, !isPaused, !isOnBreak, !stoppedWhileAway else { return }
        recorder.pause()
        stoppedWhileAway = true
    }

    private func resumeAfterAway() {
        showResumeCard = false
        stoppedWhileAway = false
        guard isRecording, isRecordingVideo, !isPaused, !isOnBreak else { return }
        recorder.resume(elapsedNow: currentElapsed)
    }

    private func setDimmed(_ dimmed: Bool) {
        guard dimmed != isDimmed else { return }
        let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen
        if dimmed {
            brightnessBeforeDim = screen?.brightness
            screen?.brightness = 0.02
        } else if let brightnessBeforeDim {
            screen?.brightness = brightnessBeforeDim
            self.brightnessBeforeDim = nil
        }
        isDimmed = dimmed
    }

    private func updateLiveActivity() {
        guard isRecording else { return }
        StudyLiveActivityController.shared.update(
            isTimer: mode == .timer,
            seconds: mode == .timer ? timerModel.remaining : stopwatchModel.elapsed,
            isPaused: isPaused || isOnBreak,
            isRecording: isRecordingVideo
        )
    }

    // アプリが途中で終了しても、次に開いたときここまでの時間を保存できるようにする
    private func saveRecoveryIfNeeded(force: Bool = false, elapsed: Int? = nil) {
        tickCount += 1
        guard force || (isRecording && tickCount % 10 == 0) else { return }
        SessionRecovery.saveSession(SessionRecoveryInfo(
            startedAt: sessionStartedAt ?? bootstrap?.startedAt ?? Date(),
            elapsedSeconds: elapsed ?? currentElapsed,
            isTimer: mode == .timer,
            updatedAt: Date()
        ))
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func clearWidgetTimerState() {
        let userDefaults = UserDefaults(suiteName: CurrentSessionDraftStore.appGroupKey) ?? .standard
        userDefaults.removeObject(forKey: "pomodoro_timer_end_timestamp")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func syncWidgetTimerStateIfNeeded(remainingSeconds: Int) {
        guard mode == .timer, remainingSeconds > 0 else { return }
        let userDefaults = UserDefaults(suiteName: CurrentSessionDraftStore.appGroupKey) ?? .standard
        let endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        userDefaults.set(endDate.timeIntervalSince1970, forKey: "pomodoro_timer_end_timestamp")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func syncWithWidgetStopState() {
        guard isRecording, mode == .timer else { return }
        let userDefaults = UserDefaults(suiteName: CurrentSessionDraftStore.appGroupKey) ?? .standard
        let timestamp = userDefaults.double(forKey: "pomodoro_timer_end_timestamp")
        if timestamp <= 0 {
            stopAndSave()
        }
    }
}

// 録画なしのときの背景。カメラの代わりに、落ち着いた色だけ出す
private struct NoCameraBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.16, green: 0.20, blue: 0.25), Color(red: 0.27, green: 0.34, blue: 0.42)],
            startPoint: .top, endPoint: .bottom
        )
        .overlay(
            Image(systemName: "video.slash")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(.white.opacity(0.35))
        )
        .accessibilityHidden(true)
    }
}
