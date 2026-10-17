import SwiftUI
import SwiftData
import UIKit
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeKit: StoreKitManager
    @AppStorage(OverlayFont.storageKey) private var overlayFontRaw = OverlayFont.standard.rawValue
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
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var recBlink = false
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
            .contentShape(Rectangle())
            // 録画中は画面をタップすると操作ボタンを出し入れできる
            .onTapGesture {
                guard isRecording else { return }
                if controlsVisible {
                    withAnimation(.easeOut(duration: 0.25)) { controlsVisible = false }
                } else {
                    showControlsTemporarily()
                }
            }

            // 文字の載る上下だけ、ごく薄く落とす
            VStack(spacing: 0) {
                LinearGradient(colors: [Color.black.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 140)
                Spacer()
                LinearGradient(colors: [.clear, Color.black.opacity(controlsVisible ? 0.4 : 0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 200)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer()

                if controlsVisible {
                    bottomControls
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .alert(videoSaved ? L10n.string("保存完了") : L10n.string("動画を保存できませんでした"), isPresented: $showSaveAlert) {
            Button(L10n.string("OK")) {
                showSaveSheet = true
            }
        } message: {
            Text(videoSaved ? L10n.string("動画を写真に保存しました。") : L10n.string("設定アプリで写真への追加を許可してください。"))
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
            VideoReviewView(result: result) { outcome in
                reviewOutcome = outcome
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
            SessionSaveView(subjectManager: subjectManager, duration: pendingDuration)
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

    // 左上にタイマー、右上に中断ボタン。中央はカメラ映像のために空けておく
    private var topBar: some View {
        HStack(alignment: .top) {
            timerBadge

            Spacer()

            if controlsVisible {
                HStack(spacing: 10) {
                    if !isRecording {
                        Button {
                            captureOrientationRaw = captureOrientation.toggled.rawValue
                        } label: {
                            Image(systemName: "rotate.right")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(L10n.format("%@に切り替える", captureOrientation.toggled.title))
                    }

                    Button {
                        showDiscardAlert = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(L10n.string("中断"))
                }
                .transition(.opacity)
            }
        }
    }

    // 動画に入る文字と同じフォントで、カードを付けずに白文字＋影で出す
    private var timerBadge: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .opacity(isRecording && !isPaused && recBlink ? 0.25 : 1)
                Text(statusText)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(1.5)
            }

            Text(displayedTime)
                .font(badgeFont.font(size: 34))
                .monospacedDigit()
                .lineLimit(1)

            Text(badgeCaption)
                .font(.system(size: 11, weight: .medium))
                .opacity(0.8)
                .lineLimit(1)
        }
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                recBlink = true
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            if recordingMode != .off && !recorder.canCaptureVideo {
                Text(L10n.string("この端末では録画できません。"))
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.85))
            }

            if !isRecording {
                VStack(spacing: 6) {
                    modeChips
                    if recordingMode == .full {
                        Text(L10n.string("全部録画は1時間で約2GB使います。"))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }

            ZStack {
                // 中央：開始／終了。左：一時停止
                HStack {
                    if isRecording {
                        Button {
                            togglePause()
                        } label: {
                            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(.ultraThinMaterial.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(L10n.string(isPaused ? "再開" : "一時停止"))
                    }
                    Spacer()
                }
                .frame(width: 240)

                Button {
                    if isRecording {
                        stopAndSave()
                    } else {
                        startRecording()
                    }
                } label: {
                    recordButtonLabel
                }
                .accessibilityLabel(L10n.string(isRecording ? "終了して保存" : "開始"))
            }
        }
        .frame(maxWidth: 520)
    }

    // カメラアプリのシャッターのような丸いボタン
    private var recordButtonLabel: some View {
        ZStack {
            Circle()
                .stroke(Color.white, lineWidth: 4)
                .frame(width: 76, height: 76)
            if isRecording {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.red)
                    .frame(width: 28, height: 28)
            } else {
                Circle()
                    .fill(isRecordingVideo ? Color.red : Color.white)
                    .frame(width: 62, height: 62)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 8)
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
                                .opacity(0.8)
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .foregroundColor(recordingMode == option ? AppPalette.ink : .white)
                    .background(
                        Capsule().fill(recordingMode == option ? Color.white : Color.black.opacity(0.3))
                    )
                }
            }
        }
    }

    private var badgeFont: OverlayFont {
        OverlayFont.resolved(rawValue: overlayFontRaw, isPro: storeKit.isProUnlocked)
    }

    private func showControlsTemporarily() {
        withAnimation(.easeOut(duration: 0.25)) { controlsVisible = true }
        scheduleControlsHide()
    }

    // 録画中は4秒で操作ボタンを隠して、カメラの映像だけにする
    private func scheduleControlsHide() {
        hideControlsTask?.cancel()
        guard isRecording else { return }
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled, isRecording, !isPaused else { return }
            withAnimation(.easeOut(duration: 0.4)) { controlsVisible = false }
        }
    }

    private var statusColor: Color {
        if isPaused { return .orange }
        if isRecording { return isRecordingVideo ? .red : .green }
        return .white.opacity(0.7)
    }

    private var statusText: String {
        if isPaused { return "PAUSE" }
        if isRecording { return isRecordingVideo ? "REC" : "FOCUS" }
        return "READY"
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
                interval: 5,
                sessionStart: startedAt,
                elapsedOffset: elapsedBeforeLaunch,
                isLandscape: captureOrientation.isLandscape
            )
        }

        isRecording = true
        isPaused = false
        UIApplication.shared.isIdleTimerDisabled = true
        scheduleControlsHide()
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

        // 一時停止中は操作ボタンを出したままにする
        if isPaused {
            hideControlsTask?.cancel()
            withAnimation(.easeOut(duration: 0.25)) { controlsVisible = true }
        } else {
            scheduleControlsHide()
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
        hideControlsTask?.cancel()
        controlsVisible = true
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
