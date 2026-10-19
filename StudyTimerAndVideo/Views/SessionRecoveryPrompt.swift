import SwiftUI

// 前回の勉強中にアプリが終了していたら、次に開いたときにそこまでの記録を保存できるようにする
struct SessionRecoveryPrompt: ViewModifier {
    @ObservedObject var subjectManager: SubjectManager
    var isEnabled: Bool

    @State private var pending: SessionRecoveryInfo?
    @State private var showAlert = false
    @State private var reviewResult: RecordingResult?
    @State private var media = SessionMedia()
    @State private var showSaveSheet = false
    @State private var didCheck = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                checkIfNeeded()
            }
            .onChange(of: isEnabled) {
                checkIfNeeded()
            }
            .alert(L10n.string("前回の記録が途中で止まっています"), isPresented: $showAlert) {
                Button(L10n.string("保存しない"), role: .destructive) {
                    SessionRecovery.discardAll()
                    pending = nil
                }
                Button(L10n.string("保存する")) {
                    openSaveFlow()
                }
            } message: {
                Text(L10n.format("%@の記録があります。保存しますか？", durationText(pending?.elapsedSeconds ?? 0)))
            }
            .fullScreenCover(item: $reviewResult, onDismiss: {
                showSaveSheet = true
            }) { result in
                VideoReviewView(result: result) { _, newMedia in
                    media = newMedia
                    reviewResult = nil
                }
            }
            .sheet(isPresented: $showSaveSheet, onDismiss: finish) {
                SessionSaveView(
                    subjectManager: subjectManager,
                    duration: pending?.elapsedSeconds ?? 0,
                    media: media,
                    date: pending?.startedAt ?? Date()
                )
            }
    }

    private func checkIfNeeded() {
        guard isEnabled, !didCheck else { return }
        didCheck = true
        StudyLiveActivityController.shared.endAll()

        guard let info = SessionRecovery.pendingSession else {
            SessionRecovery.discardAll()
            return
        }
        // 1分に満たない記録は、聞かずに片付ける
        guard info.elapsedSeconds >= 60 else {
            SessionRecovery.discardAll()
            return
        }
        pending = info
        showAlert = true
    }

    private func openSaveFlow() {
        if let recording = SessionRecovery.pendingRecording {
            reviewResult = recording
        } else {
            showSaveSheet = true
        }
    }

    private func finish() {
        SessionRecovery.discardAll()
        pending = nil
        media = SessionMedia()
    }

    private func durationText(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? L10n.format("%d時間%d分", hours, minutes) : L10n.format("%d分", max(minutes, 1))
    }
}

extension View {
    func sessionRecoveryPrompt(subjectManager: SubjectManager, isEnabled: Bool) -> some View {
        modifier(SessionRecoveryPrompt(subjectManager: subjectManager, isEnabled: isEnabled))
    }
}
