//
//  StudyReelWidget.swift
//  StudyReelWidget
//
//  Created by hw24a094 on 2025/12/18.
//

import WidgetKit
import SwiftUI
import AppIntents
import Foundation

struct PomodoroData {
    static let appGroupKey = "group.com.ni.StudyTimerAndVideo"
    static let timerEndKey = "pomodoro_timer_end_timestamp"
    static let currentSessionDraftKey = "current_session_draft"

    static func getEndTime() -> Date? {
        let userDefaults = UserDefaults(suiteName: appGroupKey)
        let timestamp = userDefaults?.double(forKey: timerEndKey) ?? 0
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }

    static func startTimer(minutes: Int) {
        let userDefaults = UserDefaults(suiteName: appGroupKey)
        let endDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        userDefaults?.set(endDate.timeIntervalSince1970, forKey: timerEndKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func saveTimerDraft(minutes: Int) {
        let draft = WidgetSessionDraft(
            id: UUID(),
            createdAt: Date(),
            startedAt: Date(),
            plannedDurationSeconds: minutes * 60,
            mode: "timer",
            source: "widget",
            shouldRecordTimelapse: true,
            requiresClassificationAfterFinish: true
        )
        saveDraft(draft)
    }

    static func saveStopwatchDraft() {
        let draft = WidgetSessionDraft(
            id: UUID(),
            createdAt: Date(),
            startedAt: Date(),
            plannedDurationSeconds: 0,
            mode: "stopwatch",
            source: "widget",
            shouldRecordTimelapse: true,
            requiresClassificationAfterFinish: true
        )
        saveDraft(draft)
    }

    static func stopTimer() {
        let userDefaults = UserDefaults(suiteName: appGroupKey)
        userDefaults?.removeObject(forKey: timerEndKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func launchURL(mode: String, minutes: Int? = nil) -> URL {
        var components = URLComponents()
        components.scheme = "studyreel"
        components.host = "start"

        var queryItems = [URLQueryItem(name: "mode", value: mode)]
        if let minutes {
            queryItems.append(URLQueryItem(name: "minutes", value: String(minutes)))
        }
        queryItems.append(URLQueryItem(name: "record", value: "1"))
        components.queryItems = queryItems

        return components.url ?? URL(string: "studyreel://start")!
    }

    private static func saveDraft(_ draft: WidgetSessionDraft) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(draft) {
            let userDefaults = UserDefaults(suiteName: appGroupKey)
            userDefaults?.set(data, forKey: currentSessionDraftKey)
        }
    }
}

struct WidgetSessionDraft: Codable {
    let id: UUID
    let createdAt: Date
    let startedAt: Date
    let plannedDurationSeconds: Int
    let mode: String
    let source: String
    let shouldRecordTimelapse: Bool
    let requiresClassificationAfterFinish: Bool
}

struct StopTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "タイマーを止める"

    func perform() async throws -> some IntentResult {
        PomodoroData.stopTimer()
        return .result()
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), endTime: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(SimpleEntry(date: Date(), endTime: PomodoroData.getEndTime()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let endTime = PomodoroData.getEndTime()
        let entries = [SimpleEntry(date: currentDate, endTime: endTime)]

        let policy: TimelineReloadPolicy
        if let endTime, endTime > currentDate {
            policy = .after(endTime)
        } else {
            policy = .never
        }

        completion(Timeline(entries: entries, policy: policy))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let endTime: Date?
}

// アプリと同じ、明るく透明感のある色
enum WidgetTheme {
    static let ink = Color(red: 0.180, green: 0.227, blue: 0.275)
    static let secondary = Color(red: 0.557, green: 0.604, blue: 0.651)
    static let accentSoft = Color(red: 0.882, green: 0.929, blue: 0.965)
    static let accentDeep = Color(red: 0.369, green: 0.553, blue: 0.722)
    static let rec = Color(red: 1.0, green: 0.36, blue: 0.33)

    static let background = LinearGradient(
        colors: [Color(red: 0.953, green: 0.965, blue: 0.976), Color(red: 0.882, green: 0.929, blue: 0.965)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func serif(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
}

struct StudyReelWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let endTime = entry.endTime, endTime > Date() {
                runningView(endTime: endTime)
            } else {
                idleView
            }
        }
        .padding(family == .systemSmall ? 14 : 16)
    }

    // タイマーが動いているとき
    private func runningView(endTime: Date) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(WidgetTheme.rec)
                        .frame(width: 6, height: 6)
                    Text("集中しています")
                        .font(.system(size: 11))
                        .foregroundStyle(WidgetTheme.secondary)
                }

                Text(endTime, style: .timer)
                    .font(WidgetTheme.serif(family == .systemSmall ? 30 : 38))
                    .foregroundStyle(WidgetTheme.ink)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                if family == .systemSmall {
                    Spacer(minLength: 0)
                    Button(intent: StopTimerIntent()) {
                        capsule("停止", systemImage: "stop.fill", filled: false)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            if family != .systemSmall {
                VStack(spacing: 8) {
                    Button(intent: StopTimerIntent()) {
                        capsule("停止", systemImage: "stop.fill", filled: false)
                    }
                    .buttonStyle(.plain)
                    Link(destination: URL(string: "studyreel://start")!) {
                        capsule("アプリを開く", systemImage: "arrow.up.right", filled: true)
                    }
                }
                .frame(width: 140)
            }
        }
    }

    // 何も動いていないとき。ここから録画を始められる
    private var idleView: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("StudyReel")
                    .font(WidgetTheme.serif(family == .systemSmall ? 18 : 22))
                    .foregroundStyle(WidgetTheme.ink)
                Text("今日も1本、撮ろう")
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetTheme.secondary)

                if family == .systemSmall {
                    Spacer(minLength: 0)
                    VStack(spacing: 6) {
                        Link(destination: PomodoroData.launchURL(mode: "timer", minutes: 25)) {
                            capsule("25分", systemImage: "timer", filled: true)
                        }
                        Link(destination: PomodoroData.launchURL(mode: "stopwatch")) {
                            capsule("ストップウォッチ", systemImage: "record.circle", filled: false)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            if family != .systemSmall {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    Link(destination: PomodoroData.launchURL(mode: "timer", minutes: 25)) {
                        capsule("25分", systemImage: "timer", filled: true)
                    }
                    Link(destination: PomodoroData.launchURL(mode: "timer", minutes: 50)) {
                        capsule("50分", systemImage: "timer", filled: false)
                    }
                    Link(destination: PomodoroData.launchURL(mode: "timer", minutes: 90)) {
                        capsule("90分", systemImage: "timer", filled: false)
                    }
                    Link(destination: PomodoroData.launchURL(mode: "stopwatch")) {
                        capsule("自由に", systemImage: "record.circle", filled: false)
                    }
                }
                .frame(width: 190)
            }
        }
    }

    private func capsule(_ title: LocalizedStringKey, systemImage: String, filled: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(filled ? Color.white : WidgetTheme.accentDeep)
            .background(Capsule().fill(filled ? WidgetTheme.accentDeep : Color.white.opacity(0.85)))
    }
}

struct StudyReelWidget: Widget {
    let kind: String = "StudyReelWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StudyReelWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetTheme.background
                }
        }
        .configurationDisplayName("StudyReel")
        .description("25分・50分・90分のタイマーや、ストップウォッチをすぐに始められます。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
