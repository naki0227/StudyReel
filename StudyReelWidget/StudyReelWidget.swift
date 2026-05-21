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

@available(iOS 17.0, *)
struct StopTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Timer"

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

struct StudyReelWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if #available(iOS 17.0, *) {
            Group {
                if let endTime = entry.endTime, endTime > Date() {
                    runningView(endTime: endTime)
                } else {
                    idleView
                }
            }
            .padding(family == .systemSmall ? 14 : 16)
        } else {
            Text("iOS 17+ Required")
        }
    }

    private func runningView(endTime: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Time")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(endTime, style: .timer)
                .font(.system(size: family == .systemSmall ? 28 : 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)

            if family == .systemSmall {
                Button(intent: StopTimerIntent()) {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 10) {
                    Button(intent: StopTimerIntent()) {
                        widgetActionLabel("Stop", systemImage: "stop.fill", tint: .red)
                    }
                    .buttonStyle(.plain)

                    Link(destination: URL(string: "studyreel://start")!) {
                        widgetActionLabel("Open App", systemImage: "arrow.up.right", tint: .blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("StudyReel")
                .font(.headline.weight(.bold))

            Text("すぐ始める")
                .font(.caption)
                .foregroundStyle(.secondary)

            if family == .systemSmall {
                VStack(spacing: 10) {
                    Link(destination: PomodoroData.launchURL(mode: "timer", minutes: 25)) {
                        widgetActionLabel("25m Focus", systemImage: "timer", tint: .blue)
                    }

                    Link(destination: PomodoroData.launchURL(mode: "stopwatch")) {
                        widgetActionLabel("Stopwatch", systemImage: "record.circle", tint: .indigo)
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    Link(destination: PomodoroData.launchURL(mode: "timer", minutes: 25)) {
                        widgetActionLabel("25m", systemImage: "timer", tint: .blue)
                    }

                    Link(destination: PomodoroData.launchURL(mode: "timer", minutes: 50)) {
                        widgetActionLabel("50m", systemImage: "timer", tint: .teal)
                    }

                    Link(destination: PomodoroData.launchURL(mode: "timer", minutes: 90)) {
                        widgetActionLabel("90m", systemImage: "timer", tint: .orange)
                    }

                    Link(destination: PomodoroData.launchURL(mode: "stopwatch")) {
                        widgetActionLabel("Stopwatch", systemImage: "record.circle", tint: .indigo)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func widgetActionLabel(_ title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(tint.opacity(0.12))
            .foregroundStyle(tint)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct StudyReelWidget: Widget {
    let kind: String = "StudyReelWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                StudyReelWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                StudyReelWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("StudyReel Quick Start")
        .description("25/50/90分やストップウォッチをすぐ開始できます。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
