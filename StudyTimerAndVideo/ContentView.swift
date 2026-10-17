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

            // 画面全体は暗くせず、文字の載る上下だけ薄く落として自分の姿を確認しやすくする
            VStack(spacing: 0) {
                LinearGradient(colors: [Color.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 160)
                Spacer()
                LinearGradient(colors: [.clear, Color.black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 220)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer()

                bottomControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
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

    // 左上にタイマー、右上に中断ボタン。中央はカメラ映像のために空けておく
    private var topBar: some View {
        HStack(alignment: .top) {
            timerBadge

            Spacer()

            if !isRecording {
                Button {
                    captureOrientationRaw = captureOrientation.toggled.rawValue
                } label: {
                    Label(captureOrientation.toggled.title, systemImage: "rotate.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(.ultraThinMaterial.opacity(0.7))
                        .clipShape(Capsule())
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
                    .background(.ultraThinMaterial.opacity(0.7))
                    .clipShape(Circle())
            }
            .accessibilityLabel(L10n.string("中断"))
        }
    }

    private var timerBadge: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
            }

            // 動画に入る文字と同じフォントで表示する
            Text(displayedTime)
                .font(OverlayFont.resolved(rawValue: overlayFontRaw, isPro: storeKit.isProUnlocked).font(size: 30))
                .monospacedDigit()
                .foregroundColor(.white)
                .lineLimit(1)

            Text(badgeCaption)
                .font(.caption2.weight(.medium))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.4))
        )
    }

    private var bottomControls: some View {
        VStack(spacing: 10) {
            if recordingMode != .off && !recorder.canCaptureVideo {
                Text(L10n.string("この端末では録画できません。"))
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
            }

            if !isRecording {
                VStack(alignment: .leading, spacing: 8) {
                    Picker(L10n.string("録画"), selection: $recordingMode) {
                        ForEach(RecordingMode.allCases) { mode in
                            Text(mode.isPro && !storeKit.isProUnlocked ? "\(mode.title) (Pro)" : mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if recordingMode == .full {
                        Text(L10n.string("全部録画は1時間で約2GB使います。"))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                )
            }

            HStack(spacing: 10) {
                if isRecording {
                    Button {
                        togglePause()
                    } label: {
                        Label(L10n.string(isPaused ? "再開" : "一時停止"), systemImage: isPaused ? "play.fill" : "pause.fill")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundColor(.white)
                            .background(Color.white.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }

                Button {
                    if isRecording {
                        stopAndSave()
                    } else {
                        startRecording()
                    }
                } label: {
                    Label(L10n.string(isRecording ? "終了して保存" : "開始"), systemImage: isRecording ? "stop.fill" : "record.circle")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundColor(AppPalette.ink)
                        .background(isRecording ? Color.white : AppPalette.sky)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .frame(maxWidth: 520)
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
