import AppIntents
import SwiftUI
import WidgetKit

// コントロールセンター・ロック画面・アクションボタンに置く「勉強を始める」。
// アプリ側（StudyTimerAndVideo/Intents/StartStudyIntent.swift）と同じ名前・同じ中身の型。どちらで動いても同じ下書きを書く
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

    var minutes: Int? {
        switch self {
        case .minutes25: return 25
        case .minutes50: return 50
        case .minutes90: return 90
        case .stopwatch: return nil
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

    func perform() async throws -> some IntentResult {
        PomodoroData.saveShortcutDraft(minutes: preset.minutes, record: record)
        return .result()
    }
}

struct StudyStartControl: ControlWidget {
    static let kind = "com.ni.StudyTimerAndVideo.StartControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartStudyIntent(preset: .minutes25)) {
                Label("勉強を始める", systemImage: "timer")
            }
        }
        .displayName("勉強を始める")
        .description("StudyReel で25分のタイマーと撮影を始めます。")
    }
}
