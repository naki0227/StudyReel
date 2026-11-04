import SwiftData
import SwiftUI

// ホームのいちばん上に出す目標。まだ目標がなければ、作るための1行だけ出す
struct HomeGoalCard: View {
    @Query(filter: #Predicate<StudyGoal> { $0.archivedAt == nil }, sort: \StudyGoal.createdAt, order: .reverse)
    private var goals: [StudyGoal]
    @Query(sort: \PastPaperResult.date) private var papers: [PastPaperResult]
    let sessions: [StudySession]
    @EnvironmentObject private var storeKit: StoreKitManager

    var onCreate: () -> Void
    var onEdit: (StudyGoal) -> Void
    var onRecordScore: () -> Void
    var onPapers: () -> Void
    var onShare: (StudyGoal) -> Void
    // ペースは Pro。Pro でない人が押したら案内を出す
    var onPro: () -> Void = {}

    var body: some View {
        if let goal = goals.first {
            card(goal, progress: GoalProgress(goal: goal, sessions: sessions, papers: papers))
        } else {
            Button(action: onCreate) {
                HStack(spacing: 8) {
                    GoalScript(text: "my goal ✦", size: 14)
                    Text(L10n.string("試験や目標を決めて、D-day を数える"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ReelTheme.accentDeep)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(ReelTheme.accent.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.goal.create")
        }
    }

    private func card(_ goal: StudyGoal, progress: GoalProgress) -> some View {
        TapedPaper {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    GoalScript(text: goal.isAchieved ? "goal achieved ✦" : "my goal ✦", size: 14)
                    Spacer()
                    Text(deadlineText(goal))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                }

                Button {
                    onEdit(goal)
                } label: {
                    HStack(alignment: .lastTextBaseline) {
                        DDayText(goal: goal, size: 54)
                        Spacer(minLength: 12)
                        Text(goal.title)
                            .font(ReelTheme.serif(20))
                            .foregroundColor(ReelTheme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.top, 8)
                    // 文字のあいだの余白も押せるようにする
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.goal.edit")

                if let target = goal.targetHours, target > 0 {
                    meterRow(
                        label: L10n.string("勉強時間"),
                        value: L10n.format("%@ / %d時間", hoursText(progress.studiedHours), target),
                        ratio: progress.hoursRatio ?? 0
                    )
                }
                if let pace = GoalPace(goal: goal, sessions: sessions) {
                    paceRow(pace)
                }
                if let target = goal.targetScore {
                    meterRow(
                        label: L10n.string("過去問の最高点"),
                        value: progress.bestScore.map { L10n.format("%d / %d点", $0, target) } ?? L10n.format("まだ記録なし / %d点", target),
                        ratio: progress.scoreRatio ?? 0
                    )
                }

                HStack(spacing: 8) {
                    action(L10n.string("点数を記録"), systemImage: "plus", id: "home.goal.score", run: onRecordScore)
                    action(L10n.string("過去問"), systemImage: "chart.line.uptrend.xyaxis", id: "home.goal.papers", run: onPapers)
                    action(L10n.string("カードで共有"), systemImage: "square.and.arrow.up", id: "home.goal.share") { onShare(goal) }
                }
                .padding(.top, 14)
            }
        }
    }

    private func paceRow(_ pace: GoalPace) -> some View {
        Button {
            if !storeKit.isProUnlocked { onPro() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: pace.leftTodaySeconds == 0 ? "checkmark.circle.fill" : "figure.walk")
                    .font(.system(size: 12))
                    .foregroundColor(ReelTheme.accentDeep)
                if storeKit.isProUnlocked {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pace.leftTodaySeconds == 0
                             ? L10n.string("今日の分は達成")
                             : L10n.format("今日あと %@", minutesText(pace.leftTodaySeconds)))
                            .font(ReelTheme.sans(13, weight: .semibold))
                            .foregroundColor(ReelTheme.ink)
                        Text(L10n.format("残り%d日・1日 %@ のペース", pace.daysLeft, minutesText(pace.perDaySeconds))
                             + (pace.isOnTrack ? "" : L10n.string("（このままだと少し足りません）")))
                            .font(ReelTheme.sans(11))
                            .foregroundColor(ReelTheme.secondary)
                    }
                } else {
                    Text(L10n.string("試験日までの1日のペースを見る"))
                        .font(ReelTheme.sans(12, weight: .medium))
                        .foregroundColor(ReelTheme.ink)
                    Text("Pro")
                        .font(ReelTheme.sans(10, weight: .semibold))
                        .foregroundColor(ReelTheme.accentDeep)
                }
                Spacer()
            }
            .padding(.top, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.goal.pace")
    }

    private func minutesText(_ seconds: Int) -> String {
        let minutes = Int((Double(seconds) / 60).rounded(.up))
        if minutes < 60 { return L10n.format("%d分", minutes) }
        return minutes % 60 == 0 ? L10n.format("%d時間", minutes / 60) : L10n.format("%d時間%d分", minutes / 60, minutes % 60)
    }

    private func meterRow(label: String, value: String, ratio: Double) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(ReelTheme.sans(11))
                    .foregroundColor(ReelTheme.secondary)
                Spacer()
                Text(value)
                    .font(ReelTheme.serif(14))
                    .foregroundColor(ReelTheme.ink)
                    .monospacedDigit()
            }
            GoalMeter(ratio: ratio)
        }
        .padding(.top, 12)
    }

    private func action(_ title: String, systemImage: String, id: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(ReelTheme.sans(11, weight: .medium))
                .foregroundColor(ReelTheme.accentDeep)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(Capsule().fill(ReelTheme.accentSoft))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func deadlineText(_ goal: StudyGoal) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MdE")
        return formatter.string(from: goal.deadline)
    }
}

func hoursText(_ hours: Double) -> String {
    hours >= 10 || hours == hours.rounded() ? String(Int(hours.rounded(.down))) : String(format: "%.1f", hours)
}
