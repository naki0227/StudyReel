import SwiftUI
import SwiftData
import UIKit
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]

    @StateObject private var recorder = TimeLapseRecorder()
    @StateObject private var timerModel = TimerViewModel()
    @StateObject private var stopwatchModel = StopwatchViewModel()

    @State private var isRecording = false
    @State private var showSaveAlert = false
    @State private var enableRecording = true
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
        _enableRecording = State(initialValue: bootstrap?.initialRecordingEnabled ?? true)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreview(recorder: recorder, isLandscape: geometry.size.width > geometry.size.height)
                    .ignoresSafeArea()

                Color.black.opacity(0.38)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    Spacer(minLength: 24)

                    focusPanel
                        .padding(.horizontal, 20)

                    Spacer(minLength: 18)

                    bottomControls
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                }
            }
        }
        .alert(L10n.string("保存完了"), isPresented: $showSaveAlert) {
            Button(L10n.string("OK")) {
                showSaveSheet = true
            }
        } message: {
            Text(L10n.string("カメラロールに動画を保存しました。"))
        }
        .alert(L10n.string("このセッションを中断しますか？"), isPresented: $showDiscardAlert) {
            Button(L10n.string("戻る"), role: .cancel) {}
            Button(L10n.string("中断する"), role: .destructive) {
                discardSession()
            }
        } message: {
            Text(L10n.string("保存せずに終了します。"))
        }
        .sheet(isPresented: $showSaveSheet, onDismiss: { onFinish() }) {
            SessionSaveView(subjectManager: subjectManager, duration: pendingDuration)
        }
        .onAppear {
            guard bootstrap?.autoStart == true, !didAutoStart else { return }
            didAutoStart = true
            startRecording()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            syncWithWidgetStopState()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                showDiscardAlert = true
            } label: {
                Label(L10n.string("中断"), systemImage: "stop.fill")
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(Color.red)
                    .clipShape(Capsule())
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial.opacity(0.6))
            .clipShape(Capsule())
        }
    }

    private var focusPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(sessionTitle)
                    .font(.headline)
                    .foregroundColor(Color.white.opacity(0.78))

                Text(sessionHeadline)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if let sourceText {
                    Text(sourceText)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Color(red: 1.0, green: 0.88, blue: 0.70))
                }
            }

            Text(displayedTime)
                .font(.system(size: 58, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            HStack(spacing: 10) {
                infoChip(title: mode == .timer ? L10n.string("タイマー") : L10n.string("自由計測"))
                infoChip(title: timelapseLabel)
            }

            if enableRecording && !recorder.canCaptureVideo {
                Text(L10n.string("この端末ではタイムラプスを記録できません。"))
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.72))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            if !isRecording {
                Toggle(L10n.string("タイムラプスを記録する"), isOn: $enableRecording)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(controlPanelBackground)
            }

            HStack(spacing: 12) {
                if isRecording {
                    Button {
                        togglePause()
                    } label: {
                        Label(L10n.string(isPaused ? "再開" : "一時停止"), systemImage: isPaused ? "play.fill" : "pause.fill")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .foregroundColor(.white)
                            .background(Color.white.opacity(0.12))
                    }
                }

                Button {
                    if isRecording {
                        stopAndSave()
                    } else {
                        startRecording()
                    }
                } label: {
                    Text(L10n.string(isRecording ? "終了して保存" : "開始"))
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .foregroundColor(.white)
                        .background(isRecording ? Color.green.opacity(0.95) : Color.green)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.15, blue: 0.22).opacity(0.88),
                        Color(red: 0.04, green: 0.09, blue: 0.14).opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }

    private var controlPanelBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.black.opacity(0.28))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private func infoChip(title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.10))
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        if isPaused { return .orange }
        if isRecording { return .green }
        return .white.opacity(0.7)
    }

    private var statusText: String {
        if isPaused { return L10n.string("一時停止中") }
        if isRecording { return L10n.string("計測中") }
        return L10n.string("開始前")
    }

    private var sessionTitle: String {
        mode == .timer ? L10n.string("タイマーセッション") : L10n.string("自由計測")
    }

    private var sessionHeadline: String {
        if mode == .timer {
            return bootstrap?.source == .widget ? L10n.string("すぐに集中を始める") : L10n.string("いまの25分を積み上げる")
        }
        return L10n.string("時間を決めずに集中する")
    }

    private var sourceText: String? {
        guard bootstrap?.source == .widget else { return nil }
        return L10n.string("Widgetから開始")
    }

    private var displayedTime: String {
        formatTime(mode == .timer ? timerModel.remaining : stopwatchModel.elapsed)
    }

    private var timelapseLabel: String {
        if !enableRecording { return L10n.string("タイムラプスオフ") }
        return recorder.canCaptureVideo ? L10n.string("タイムラプスオン") : L10n.string("タイムラプス利用不可")
    }

    private func startRecording() {
        let elapsedBeforeLaunch = bootstrap?.elapsedSecondsAtLaunch ?? 0
        sessionStartedAt = bootstrap?.startedAt ?? Date()

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

        if enableRecording && recorder.canCaptureVideo {
            recorder.startCapturing(interval: 5)
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

            if enableRecording && recorder.canCaptureVideo {
                recorder.resumeCapturing(interval: 5)
            }
            isPaused = false
        } else {
            if mode == .timer {
                timerModel.pause()
            } else {
                stopwatchModel.pause()
            }

            if enableRecording && recorder.canCaptureVideo {
                recorder.pauseCapturing()
            }
            isPaused = true
        }
    }

    private func stopAndSave() {
        let completedDuration = mode == .timer ? max(totalSeconds - timerModel.remaining, 0) : stopwatchModel.elapsed
        pendingDuration = completedDuration

        if enableRecording && recorder.canCaptureVideo {
            recorder.stopCapturing()
            recorder.exportToVideo { url in
                if let url {
                    UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
                }
                DispatchQueue.main.async {
                    showSaveAlert = true
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
        recorder.stopCapturing()
        isRecording = false
        isPaused = false
        sessionStartedAt = nil
        clearWidgetTimerState()
        onFinish()
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02dh%02dm%02ds", hours, minutes, seconds)
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
