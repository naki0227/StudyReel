import SwiftUI
import SwiftData
import UIKit
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeKit: StoreKitManager
    @AppStorage(OverlayFont.storageKey) private var overlayFontRaw = OverlayFont.defaultFont.rawValue
    @AppStorage(CaptureOrientation.storageKey) private var captureOrientationRaw = CaptureOrientation.landscape.rawValue
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]

    @StateObject private var recorder = TimeLapseRecorder()
    @StateObject private var timerModel = TimerViewModel()
    @StateObject private var stopwatchModel = StopwatchViewModel()

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
        _recordingMode = State(initialValue: (bootstrap?.initialRecordingEnabled ?? true) ? .timelapse : .off)
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                CameraPreview(recorder: recorder, isLandscape: geometry.size.width > geometry.size.height)
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
            SessionSaveView(subjectManager: subjectManager, duration: pendingDuration, media: pendingMedia)
        }
        .onChange(of: captureOrientationRaw) {
            OrientationLock.lock(captureOrientation.mask)
        }
        .onAppear {
            OrientationLock.lock(captureOrientation.mask)
            guard bootstrap?.autoStart == true, !didAutoStart else { return }
            didAutoStart = true
            startRecording()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            syncWithWidgetStopState()
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
                    shutterButton
                    if isRecording {
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
                            pauseButton
                            Spacer()
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
                .accessibilityLabel(L10n.format("%@に切り替える", captureOrientation.toggled.title))
            }

            if recordingMode != .off && !recorder.canCaptureVideo {
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
        }
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 1)
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

    private var modeChips: some View {
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

    private var storageNote: some View {
        Text(L10n.string("全部録画は1時間で約2GB使います。"))
            .font(ReelTheme.sans(11))
            .foregroundColor(.white.opacity(0.85))
            .shadow(color: .black.opacity(0.4), radius: 4)
    }

    private var statusColor: Color {
        if isPaused { return .orange }
        if isRecording { return isRecordingVideo ? .red : .green }
        return .white.opacity(0.7)
    }

    private var statusText: String {
        if isPaused { return L10n.string("一時停止中") }
        if isRecording { return L10n.string(isRecordingVideo ? "録画中" : "計測中") }
        return L10n.string("開始前")
    }

    private var badgeCaption: String {
        var parts = [mode == .timer ? L10n.string("タイマー") : L10n.string("ストップウォッチ")]
        parts.append(recordingLabel)
        if bootstrap?.source == .widget {
            parts.append(L10n.string("Widgetから開始"))
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

    private var isRecordingVideo: Bool {
        recordingMode != .off && recorder.canCaptureVideo
    }

    private var recordingLabel: String {
        if recordingMode != .off && !recorder.canCaptureVideo { return L10n.string("録画できません") }
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
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func togglePause() {
        if isPaused {
            if mode == .timer {
                timerModel.resume {
                    stopAndSave()
                }
            } else {
                stopwatchModel.resume()
            }

            if isRecordingVideo {
                recorder.resume()
            }
            isPaused = false
        } else {
            if mode == .timer {
                timerModel.pause()
            } else {
                stopwatchModel.pause()
            }

            if isRecordingVideo {
                recorder.pause()
            }
            isPaused = true
        }
    }

    private func stopAndSave() {
        let completedDuration = mode == .timer ? max(totalSeconds - timerModel.remaining, 0) : stopwatchModel.elapsed
        pendingDuration = completedDuration

        if isRecordingVideo {
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
        sessionStartedAt = nil
        UIApplication.shared.isIdleTimerDisabled = false
        clearWidgetTimerState()
    }

    private func discardSession() {
        UIApplication.shared.isIdleTimerDisabled = false
        timerModel.stop()
        stopwatchModel.stop()
        recorder.cancel()
        isRecording = false
        isPaused = false
        sessionStartedAt = nil
        clearWidgetTimerState()
        finishSession()
    }

    // 録画画面を閉じるときだけ向きの固定を外す（確認画面を出している間は固定したまま）
    private func finishSession() {
        OrientationLock.unlock()
        onFinish()
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
