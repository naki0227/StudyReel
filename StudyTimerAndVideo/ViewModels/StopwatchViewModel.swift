import UIKit

//MARK: - ストップウォッチ管理
class StopwatchViewModel: ObservableObject {
    @Published var elapsed: Int = 0
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
    
    func start() {
        elapsed = 0
        isPaused = false
        startTimer()
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsed += 1
        }
    }
    
    func pause() {
        isPaused = true
        timer?.invalidate()
    }
    
    func resume() {
        isPaused = false
        startTimer()
    }
    
    func stop() {
        isPaused = false
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func appMovedToBackground() {
        if !isPaused {
            lastBackgroundDate = Date()
        }
    }
    
    @objc private func appMovedToForeground() {
        guard let backgroundDate = lastBackgroundDate, !isPaused else { return }
        let timePassed = Date().timeIntervalSince(backgroundDate)
        elapsed += Int(timePassed)
        lastBackgroundDate = nil
    }
}
