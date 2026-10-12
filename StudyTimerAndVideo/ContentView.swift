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
        .alert(L10n.string("保存完了"), isPresented: $showSaveAlert) {
            Button(L10n.string("OK")) {
                showSaveSheet = true
            }
        } message: {
            Text(L10n.string("タイムラプスを写真に保存しました。"))
        }
        .alert(L10n.string("記録を中断しますか？"), isPresented: $showDiscardAlert) {
            Button(L10n.string("戻る"), role: .cancel) {}
            Button(L10n.string("中断する"), role: .destructive) {
                discardSession()
            }
        } message: {
            Text(L10n.string("ここまでの記録は保存されません。"))
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

    // 左上にタイマー、右上に中断ボタン。中央はカメラ映像のために空けておく
    private var topBar: some View {
        HStack(alignment: .top) {
            timerBadge

            Spacer()

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

            Text(displayedTime)
                .font(.system(size: 30, weight: .bold, design: .rounded))
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
            if enableRecording && !recorder.canCaptureVideo {
                Text(L10n.string("この端末ではタイムラプスを記録できません。"))
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
            }

            if !isRecording {
                Toggle(L10n.string("タイムラプスを記録する"), isOn: $enableRecording)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .tint(AppPalette.sky)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
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
        if isRecording { return enableRecording && recorder.canCaptureVideo ? .red : .green }
        return .white.opacity(0.7)
    }

    private var statusText: String {
        if isPaused { return L10n.string("一時停止中") }
        if isRecording { return L10n.string(enableRecording && recorder.canCaptureVideo ? "録画中" : "計測中") }
        return L10n.string("開始前")
    }

    private var badgeCaption: String {
        var parts = [mode == .timer ? L10n.string("タイマー") : L10n.string("ストップウォッチ")]
        parts.append(timelapseLabel)
        if bootstrap?.source == .widget {
            parts.append(L10n.string("Widgetから開始"))
        }
        return parts.joined(separator: " · ")
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
