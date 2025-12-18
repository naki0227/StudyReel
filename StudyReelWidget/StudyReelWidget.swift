//
//  StudyReelWidget.swift
//  StudyReelWidget
//
//  Created by hw24a094 on 2025/12/18.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Data Layer
struct PomodoroData {
    static let appGroupKey = "group.com.ni.StudyTimerAndVideo" // Ensure this matches everywhere
    static let timerEndKey = "pomodoro_timer_end_timestamp"
    
    static func getEndTime() -> Date? {
        let userDefaults = UserDefaults(suiteName: appGroupKey)
        let timestamp = userDefaults?.double(forKey: timerEndKey) ?? 0
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
    
    static func startTimer(minutes: Int) {
        let userDefaults = UserDefaults(suiteName: appGroupKey)
        let endDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        userDefaults?.set(endDate.timeIntervalSince1970, forKey: timerEndKey)
    }
    
    static func stopTimer() {
        let userDefaults = UserDefaults(suiteName: appGroupKey)
        userDefaults?.removeObject(forKey: timerEndKey)
    }
}

// MARK: - App Intents (Interactivity)
@available(iOS 17.0, *)
struct StartTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Pomodoro"
    
    // Parameter to allow different durations if needed in future
    @Parameter(title: "Duration")
    var duration: Int
    
    init() {
        self.duration = 25
    }
    
    init(duration: Int) {
        self.duration = duration
    }
    
    func perform() async throws -> some IntentResult {
        PomodoroData.startTimer(minutes: duration)
        return .result()
    }
}

@available(iOS 17.0, *)
struct StopTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Timer"
    
    func perform() async throws -> some IntentResult {
        PomodoroData.stopTimer()
        return .result()
    }
}

// MARK: - Widget Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), endTime: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), endTime: PomodoroData.getEndTime())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let endTime = PomodoroData.getEndTime()
        
        // If timer is running, update when it finishes
        let entries = [SimpleEntry(date: currentDate, endTime: endTime)]
        
        let policy: TimelineReloadPolicy
        if let endTime = endTime, endTime > currentDate {
            policy = .after(endTime) // Refresh when timer ends
        } else {
            policy = .never // Wait for user interaction
        }
        
        let timeline = Timeline(entries: entries, policy: policy)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let endTime: Date?
}

// MARK: - Widget View
struct StudyReelWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        if #available(iOS 17.0, *) {
            VStack {
                if let endTime = entry.endTime, endTime > Date() {
                    // Running State
                    Text("Focus Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(endTime, style: .timer) // System countdown
                        .multilineTextAlignment(.center)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .minimumScaleFactor(0.5)
                        .padding(.vertical, 8)
                    
                    Button(intent: StopTimerIntent()) {
                        Text("Stop")
                            .font(.caption)
                            .bold()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    
                } else {
                    // Idle State
                    Text("Ready to Focus?")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    Button(intent: StartTimerIntent(duration: 25)) {
                        Label("Start 25m", systemImage: "timer")
                            .font(.system(size: 16, weight: .bold))
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            Text("iOS 17+ Required for Interactivity")
        }
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
        .configurationDisplayName("Pomodoro Timer")
        .description("Start a 25-minute focus timer.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    StudyReelWidget()
} timeline: {
    SimpleEntry(date: .now, endTime: nil)
    SimpleEntry(date: .now, endTime: Date().addingTimeInterval(1500)) // 25 min remaining
}
