import ActivityKit
import SwiftUI
import WidgetKit

// 勉強中にロック画面と Dynamic Island に出す表示
struct StudyLiveActivity: Widget {
    private let stopURL = URL(string: "studyreel://stop")!

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color(red: 0.953, green: 0.965, blue: 0.976))
                .activitySystemActionForegroundColor(WidgetTheme.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(statusTitle(context.state))
                    } icon: {
                        statusDot(context.state)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Link(destination: stopURL) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                    .accessibilityLabel(Text("停止"))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    timeText(context)
                        .font(.system(size: 40, weight: .regular, design: .serif))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
            } compactLeading: {
                statusDot(context.state)
                    .padding(.leading, 2)
            } compactTrailing: {
                timeText(context)
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .frame(maxWidth: 56)
                    .foregroundStyle(.white)
            } minimal: {
                statusDot(context.state)
            }
            .keylineTint(WidgetTheme.accentDeep)
        }
    }

    private func lockScreen(_ context: ActivityViewContext<StudyActivityAttributes>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    statusDot(context.state)
                    Text(statusTitle(context.state))
                        .font(.system(size: 12))
                        .foregroundStyle(WidgetTheme.secondary)
                }
                timeText(context)
                    .font(WidgetTheme.serif(36))
                    .foregroundStyle(WidgetTheme.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                Text(context.attributes.isTimer ? "タイマー" : "ストップウォッチ")
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetTheme.secondary)
            }
            Spacer()
            Link(destination: stopURL) {
                Label("停止", systemImage: "stop.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetTheme.accentDeep)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.white.opacity(0.9)))
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private func timeText(_ context: ActivityViewContext<StudyActivityAttributes>) -> some View {
        let state = context.state
        if state.isPaused {
            Text(Self.format(state.pausedSeconds))
        } else if let end = state.timerEnd {
            if end > Date() {
                Text(timerInterval: Date()...end, countsDown: true)
            } else {
                Text("00:00")
            }
        } else if let start = state.countingFrom {
            Text(start, style: .timer)
        } else {
            Text(Self.format(state.pausedSeconds))
        }
    }

    private func statusDot(_ state: StudyActivityAttributes.ContentState) -> some View {
        Circle()
            .fill(state.isPaused ? Color.orange : (state.isRecording ? WidgetTheme.rec : Color.green))
            .frame(width: 8, height: 8)
    }

    private func statusTitle(_ state: StudyActivityAttributes.ContentState) -> LocalizedStringKey {
        if state.isPaused { return "一時停止中" }
        return state.isRecording ? "録画しながら勉強中" : "勉強中"
    }

    private static func format(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%02d:%02d", minutes, secs)
    }
}
