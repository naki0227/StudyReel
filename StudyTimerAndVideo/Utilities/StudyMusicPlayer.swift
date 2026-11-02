import AVFoundation
import Combine

// 勉強中に流す音。動画用の4曲に、定番の環境音を足したもの
enum StudySound: String, CaseIterable, Identifiable {
    static let storageKey = "study_sound"

    case none
    case rain
    case brownNoise
    case whiteNoise
    case morning
    case lofiStudy
    case coffeeTime
    case piano

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return L10n.string("なし")
        case .rain: return L10n.string("雨の音")
        case .brownNoise: return L10n.string("集中ノイズ")
        case .whiteNoise: return L10n.string("ホワイトノイズ")
        case .morning, .lofiStudy, .coffeeTime, .piano: return track?.title ?? ""
        }
    }

    var systemImage: String {
        switch self {
        case .none: return "speaker.slash"
        case .rain: return "cloud.rain"
        case .brownNoise: return "waveform"
        case .whiteNoise: return "wind"
        default: return "music.note"
        }
    }

    // 動画の BGM と同じ曲は、同じ無料・Pro の区別にする
    var isPro: Bool { track?.isPro ?? false }

    var track: BGMTrack? {
        switch self {
        case .morning: return .morning
        case .lofiStudy: return .lofiStudy
        case .coffeeTime: return .coffeeTime
        case .piano: return .piano
        default: return nil
        }
    }

    var url: URL? {
        switch self {
        case .none: return nil
        case .rain: return Bundle.main.url(forResource: "Rain", withExtension: "m4a")
        case .brownNoise: return Bundle.main.url(forResource: "BrownNoise", withExtension: "m4a")
        case .whiteNoise: return Bundle.main.url(forResource: "WhiteNoise", withExtension: "m4a")
        default: return track?.url
        }
    }
}

// 音の大きさ。読む・覚える勉強では大きい音ほど邪魔になるので、既定は小さめ（docs/research/science.md）
enum StudySoundVolume: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    static let storageKey = "study_sound_volume"

    var id: String { rawValue }

    var value: Float {
        switch self {
        case .low: return 0.25
        case .medium: return 0.45
        case .high: return 0.7
        }
    }

    var title: String {
        switch self {
        case .low: return L10n.string("小さめ")
        case .medium: return L10n.string("ふつう")
        case .high: return L10n.string("大きめ")
        }
    }

    static var saved: StudySoundVolume {
        StudySoundVolume(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .medium
    }
}

// 録画画面で音をくり返し流す。ほかのアプリの音楽を止めないよう、混ぜて鳴らす
@MainActor
final class StudyMusicPlayer: ObservableObject {
    @Published private(set) var sound: StudySound = .none

    private var player: AVAudioPlayer?
    private var isHeld = false
    private var interruptionObserver: NSObjectProtocol?

    init() {
        // 電話や Siri で止められたあと、止めていなければ鳴らし直す
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            Task { @MainActor in
                guard let self, !self.isHeld, let player = self.player else { return }
                try? AVAudioSession.sharedInstance().setActive(true)
                player.play()
            }
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    func setVolume(_ volume: StudySoundVolume) {
        player?.volume = volume.value
    }

    func play(_ newSound: StudySound) {
        sound = newSound
        player?.stop()
        player = nil
        guard let url = newSound.url else { return }

        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.volume = StudySoundVolume.saved.value
        player?.prepareToPlay()
        if !isHeld {
            player?.play()
        }
    }

    // 一時停止中やアプリを離れている間は止めておく
    func hold(_ held: Bool) {
        isHeld = held
        if held {
            player?.pause()
        } else {
            player?.play()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
