import SwiftUI
import SwiftData

// MARK: - メインUI
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @StateObject var recorder = TimeLapseRecorder()
    @StateObject var timerModel = TimerViewModel()
    @StateObject var stopwatchModel = StopwatchViewModel()
    
    @State private var isRecording = false
    @State private var showSaveAlert = false
    @State private var showSubjectPicker = false
    @State private var selectedSubject: String = ""
    
    @State private var showSaveSheet = false
    @State private var pendingDuration = 0
    
    @State private var isPaused = false
    
    var subjectManager: SubjectManager
    // Removed logManager
    var totalSeconds: Int
    var onFinish: () -> Void
    var mode: Mode
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                CameraPreview(recorder: recorder)
                    .ignoresSafeArea()
                
                // Controls Overlay
                if isLandscape {
                    HStack {
                        // Left controls (Back)
                        VStack {
                            backButton
                            Spacer()
                        }
                        Spacer()
                        
                        // Center (Timer)
                        VStack {
                            timerDisplay
                            Spacer()
                        }
                        
                        Spacer()
                        
                        // Right controls (Action)
                        VStack {
                            Spacer()
                            actionButtons
                        }
                    }
                    .padding()
                } else {
                    VStack {
                        HStack {
                            backButton
                            Spacer()
                        }
                        .padding(.top, 40)
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        timerDisplay
                        
                        Spacer()
                        
                        actionButtons
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .alert("保存完了", isPresented: $showSaveAlert) {
            Button("OK") {
                showSaveSheet = true
            }
        } message: {
            Text("カメラロールに動画を保存しました。")
        }

        .sheet(isPresented: $showSaveSheet, onDismiss: { onFinish() }) {
            SessionSaveView(subjectManager: subjectManager, duration: pendingDuration)
        }
    }
    
    var backButton: some View {
        Button(action: {
            timerModel.stop()
            stopwatchModel.stop()
            recorder.stopCapturing()
            onFinish()
        }) {
            Image(systemName: "chevron.left")
                .font(.title2)
                .padding(12)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
                .foregroundColor(.white)
        }
    }
    
    var timerDisplay: some View {
        Text(mode == .timer ?
             formatTime(timerModel.remaining):
                formatTime(stopwatchModel.elapsed))
            .font(.largeTitle)
            .fontWeight(.bold)
            .padding()
            .background(Color.black.opacity(0.6))
            .foregroundColor(.white)
            .cornerRadius(12)
    }
    
    var actionButtons: some View {
        HStack(spacing: 20) {
            if isRecording {
                Button(action: {
                    togglePause()
                }) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.title)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
            
            Button(isRecording ? "終了して保存" : "録画開始") {
                if isRecording {
                    stopAndSave()
                } else {
                    startRecording()
                }
            }
            .padding()
            .frame(width: 200)
            .background(isRecording ? Color.red : Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
    
    private func startRecording() {
        if mode == .timer {
            timerModel.start(seconds: totalSeconds) {
                stopAndSave()
            }
        } else {
            stopwatchModel.start()
        }
        
        recorder.startCapturing(interval: 5)
        isRecording = true
        isPaused = false
    }
    
    private func togglePause() {
        if isPaused {
            // Resume
            if mode == .timer {
                timerModel.resume { stopAndSave() }
            } else {
                stopwatchModel.resume()
            }
            recorder.resumeCapturing(interval: 5)
            isPaused = false
        } else {
            // Pause
            if mode == .timer {
                timerModel.pause()
            } else {
                stopwatchModel.pause()
            }
            recorder.pauseCapturing()
            isPaused = true
        }
    }
    
    private func stopAndSave() {
        recorder.stopCapturing()
        recorder.exportToVideo { url in
            if let url = url {
                UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
            }
            DispatchQueue.main.async {
                showSaveAlert = true
            }
        }
        timerModel.stop()
        stopwatchModel.stop()
        
        // Calculate duration
        if mode == .timer {
            pendingDuration = totalSeconds - timerModel.remaining
        } else {
            pendingDuration = stopwatchModel.elapsed
        }
        
        isRecording = false
        isPaused = false
        
        // Show save sheet after alert (or concurrently? Alert is for video save, Sheet is for session save)
        // Let's show alert first, then sheet? Or just show sheet and say "Video saved" in it?
        // Current flow: Alert "Video Saved" -> OK -> Finish.
        // New flow: Alert "Video Saved" -> OK -> Show SessionSaveView -> Save -> Finish.
        // But `showSaveAlert` OK button calls `onFinish`.
        // I should change `showSaveAlert` to NOT call `onFinish`, but instead set `showSaveSheet = true`.
    }
    
    func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02dh%02dm%02ds", hours, minutes, seconds)
    }
}
