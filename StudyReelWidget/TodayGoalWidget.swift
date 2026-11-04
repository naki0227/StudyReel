import SwiftUI
import WidgetKit

// 「今日の目標まであと◯分」（Pro）。ホーム画面とロック画面に置ける。数字はアプリが App Group に書く
struct TodayGoalEntry: TimelineEntry {
    let date: Date
    let todaySeconds: Int
    let goalSeconds: Int
    let isPro: Bool

    var leftMinutes: Int { max(0, Int((Double(goalSeconds - todaySeconds) / 60).rounded(.up))) }
    var studiedMinutes: Int { todaySeconds / 60 }
    var ratio: Double { goalSeconds > 0 ? min(Double(todaySeconds) / Double(goalSeconds), 1) : 0 }
}

struct TodayGoalProvider: TimelineProvider {
    private static let suiteName = "group.com.ni.StudyTimerAndVideo"

    func placeholder(in context: Context) -> TodayGoalEntry {
        TodayGoalEntry(date: Date(), todaySeconds: 45 * 60, goalSeconds: 120 * 60, isPro: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayGoalEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

    // 日付が変わったら 0 から数え直す
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayGoalEntry>) -> Void) {
        let midnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 3600 + 60)
        completion(Timeline(entries: [current()], policy: .after(midnight)))
    }

    private func current(now: Date = Date()) -> TodayGoalEntry {
        let defaults = UserDefaults(suiteName: Self.suiteName)
        let today = Calendar.current.startOfDay(for: now).timeIntervalSince1970
        let isToday = defaults?.double(forKey: "today_widget_day") == today
        return TodayGoalEntry(
            date: now,
            todaySeconds: isToday ? (defaults?.integer(forKey: "today_widget_seconds") ?? 0) : 0,
            goalSeconds: defaults?.integer(forKey: "today_widget_goal") ?? 0,
            isPro: defaults?.bool(forKey: "today_widget_pro") ?? false
        )
    }
}

struct TodayGoalWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayGoalEntry

    var body: some View {
        if !entry.isPro {
            locked
        } else if entry.goalSeconds == 0 {
            noGoal
        } else {
            switch family {
            case .accessoryCircular:
                Gauge(value: entry.ratio) {
                    Text("目標")
                } currentValueLabel: {
                    Text(entry.leftMinutes == 0 ? "✓" : "\(entry.leftMinutes)")
                }
                .gaugeStyle(.accessoryCircularCapacity)
            case .accessoryInline:
                if entry.leftMinutes == 0 { Text("今日の目標は達成") } else { Text("今日の目標まであと \(entry.leftMinutes) 分") }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Group {
                        if entry.leftMinutes == 0 { Text("今日の目標は達成") } else { Text("今日あと \(entry.leftMinutes) 分") }
                    }
                    .font(.headline)
                    ProgressView(value: entry.ratio)
                    Text("今日 \(entry.studiedMinutes) 分")
                        .font(.caption2)
                }
            default:
                VStack(alignment: .leading, spacing: 6) {
                    Text("StudyReel")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundStyle(WidgetTheme.accentDeep)
                    Spacer(minLength: 0)
                    Group {
                        if entry.leftMinutes == 0 { Text("達成") } else { Text("あと") }
                    }
                    .font(.system(size: 12))
                        .foregroundStyle(WidgetTheme.secondary)
                    if entry.leftMinutes > 0 {
                        Text("\(entry.leftMinutes) 分")
                            .font(.system(size: 30, weight: .semibold, design: .serif))
                            .foregroundStyle(WidgetTheme.ink)
                            .minimumScaleFactor(0.6)
                    }
                    ProgressView(value: entry.ratio)
                        .tint(WidgetTheme.accentDeep)
                    Text("今日 \(entry.studiedMinutes) 分")
                        .font(.system(size: 11))
                        .foregroundStyle(WidgetTheme.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var locked: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "lock.fill")
            Text("Pro で使えます")
                .font(.caption)
        }
    }

    private var noGoal: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "target")
            Text("アプリで1日の目標を決めてください")
                .font(.caption)
                .minimumScaleFactor(0.7)
        }
    }
}

struct TodayGoalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StudyReelToday", provider: TodayGoalProvider()) { entry in
            TodayGoalWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetTheme.background
                }
        }
        .configurationDisplayName("今日の目標")
        .description("今日の目標まであと何分かを、ホーム画面やロック画面に出します。")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}
