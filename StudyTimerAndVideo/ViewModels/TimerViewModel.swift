import UIKit

// MARK: - タイマー管理
class TimerViewModel: ObservableObject {
    @Published var remaining: Int = 0
    @Published var isPaused: Bool = false
    private var timer: Timer?
    private var lastBackgroundDate: Date?
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func start(seconds: Int, onFinish: @escaping () -> Void) {
        remaining = seconds
        isPaused = false
        startTimer(onFinish: onFinish)
    }
    
    private func startTimer(onFinish: @escaping () -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self = self else { return }
            if self.remaining > 0 {
                self.remaining -= 1
            } else {
                t.invalidate()
                onFinish()
            }
        }
    }
    
    func pause() {
        isPaused = true
        timer?.invalidate()
    }
    
    func resume(onFinish: @escaping () -> Void) {
        isPaused = false
        startTimer(onFinish: onFinish)
    }
    
    func stop() {
        isPaused = false
        timer?.invalidate()
    }
    
    @objc private func appMovedToBackground() {
        if !isPaused {
            lastBackgroundDate = Date()
        }
    }
    
    @objc private func appMovedToForeground() {
        guard let backgroundDate = lastBackgroundDate, !isPaused else { return }
        let timePassed = Date().timeIntervalSince(backgroundDate)
        let secondsPassed = Int(timePassed)
        
        if remaining > secondsPassed {
            remaining -= secondsPassed
        } else {
            remaining = 0
            // Timer will handle finish on next tick or we could force it here
        }
        lastBackgroundDate = nil
    }
}
