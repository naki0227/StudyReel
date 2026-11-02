import AppIntents
import Foundation

// Siri・ショートカット・アクションボタン・コントロールセンターから勉強を始める。
// ここでは下書きを App Group に書いてアプリを開くだけで、カメラはアプリが前に出てから使う（StartView が下書きを読む）。
// ウィジェット側（StudyReelWidget/StudyStartControl.swift）にも同じ名前の型があり、どちらで動いても同じ下書きを書く
enum StudyPreset: String, AppEnum {
    case minutes25
    case minutes50
    case minutes90
    case stopwatch

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "時間"
    static let caseDisplayRepresentations: [StudyPreset: DisplayRepresentation] = [
        .minutes25: "25分",
        .minutes50: "50分",
        .minutes90: "90分",
        .stopwatch: "ストップウォッチ"
    ]

    var seconds: Int {
        switch self {
        case .minutes25: return 25 * 60
        case .minutes50: return 50 * 60
        case .minutes90: return 90 * 60
        case .stopwatch: return 0
        }
    }
}

struct StartStudyIntent: AppIntent {
    static let title: LocalizedStringResource = "勉強を始める"
    static let description = IntentDescription("StudyReel を開いて、タイマーと撮影を始めます。")
    static let openAppWhenRun = true

    @Parameter(title: "時間", default: .minutes25)
    var preset: StudyPreset

    @Parameter(title: "撮影する", default: true)
    var record: Bool

    init() {}

    init(preset: StudyPreset, record: Bool = true) {
        self.preset = preset
        self.record = record
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let draft: CurrentSessionDraft = preset == .stopwatch
            ? .stopwatch(source: .shortcut, shouldRecordTimelapse: record)
            : .timer(durationSeconds: preset.seconds, source: .shortcut, shouldRecordTimelapse: record)
        CurrentSessionDraftStore().save(draft)
        return .result()
    }
}

struct StudyReelShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartStudyIntent(),
            phrases: [
                "\(.applicationName)で勉強を始める",
                "\(.applicationName)で\(\.$preset)勉強する"
            ],
            shortTitle: "勉強を始める",
            systemImageName: "timer"
        )
    }
}
