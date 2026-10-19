import Charts
import SwiftData
import SwiftUI

// 過去問・模試の点数の記録と推移。問題ごとに何回目で何点伸びたかを並べる
struct PastPapersView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PastPaperResult.date) private var results: [PastPaperResult]
    @Query(filter: #Predicate<StudyGoal> { $0.archivedAt == nil }, sort: \StudyGoal.createdAt, order: .reverse)
    private var goals: [StudyGoal]

    @State private var editing: PastPaperResult?
    @State private var addingPaper: String?
    @State private var showAdd = false
    @State private var showShare = false
    @State private var sharePaper: String?
    @State private var order: PaperOrder = .byPaper

    private var goal: StudyGoal? { goals.first }

    // グラフに出すのは、目標と同じ満点の回（目標がなければ、いちばん多い満点）
    private var chartResults: [PastPaperResult] {
        let scored = results.filter { $0.score != nil }
        if let max = goal?.maxScore { return scored.filter { $0.maxScore == max } }
        let counts = Dictionary(grouping: scored) { $0.maxScore ?? 0 }
        guard let common = counts.max(by: { $0.value.count < $1.value.count })?.key else { return [] }
        return scored.filter { ($0.maxScore ?? 0) == common }
    }

    private var series: [PaperSeries] { PaperSeries.group(results) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if results.isEmpty {
                        emptyState
                    } else {
                        chartCard
                        Picker("", selection: $order) {
                            ForEach(PaperOrder.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        switch order {
                        case .byPaper:
                            ForEach(series) { item in seriesCard(item) }
                        case .byDate:
                            ForEach(results.reversed()) { result in dateRow(result) }
                        }

                        if series.contains(where: { $0.gain != nil }) {
                            Button {
                                sharePaper = series.first { $0.gain != nil }?.name
                                showShare = true
                            } label: {
                                Label(L10n.string("伸びをカードで共有"), systemImage: "square.and.arrow.up")
                                    .font(ReelTheme.sans(14, weight: .medium))
                                    .foregroundColor(ReelTheme.accentDeep)
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .background(Capsule().fill(ReelTheme.accentSoft))
                            }
                            .accessibilityIdentifier("papers.share")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(GridPaperBackground().ignoresSafeArea())
            .navigationTitle(L10n.string("過去問・模試"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("閉じる")) { dismiss() }
                        .foregroundColor(ReelTheme.ink)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addingPaper = nil
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(L10n.string("点数を記録"))
                    .accessibilityIdentifier("papers.add")
                }
            }
            .sheet(isPresented: $showAdd) {
                ScoreRecordSheet(result: nil, paperName: addingPaper)
            }
            .sheet(item: $editing) { result in
                ScoreRecordSheet(result: result, paperName: nil)
            }
            .sheet(isPresented: $showShare) {
                GoalShareView(goal: goal, initialKind: .scoreUp, initialPaper: sharePaper)
            }
        }
        .tint(ReelTheme.accentDeep)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            GoalScript(text: "past papers ✦", size: 18)
            Text(L10n.string("過去問や模試を解いたら、点数を残しておきましょう。同じ問題を2回目、3回目と解くと、伸びが見えます。"))
                .font(ReelTheme.sans(13))
                .foregroundColor(ReelTheme.secondary)
                .multilineTextAlignment(.center)
            Button {
                showAdd = true
            } label: {
                Text(L10n.string("点数を記録"))
                    .font(ReelTheme.sans(15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .frame(minHeight: 46)
                    .background(Capsule().fill(ReelTheme.accentDeep))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var chartCard: some View {
        let points = chartResults
        let best = points.compactMap(\.score).max()
        let gain: Int? = {
            guard let first = points.first?.score, let best, points.count >= 2 else { return nil }
            return best - first
        }()
        return TapedPaper(tape: GoalTheme.tapeYellow, tapeAlignment: .top, tapeAngle: -2) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    GoalScript(text: "best", size: 14)
                    Text(best.map(String.init) ?? "—")
                        .font(ReelTheme.serif(30))
                        .foregroundColor(ReelTheme.ink)
                    Text(L10n.string("点"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                    Spacer()
                    if let gain, gain != 0 {
                        Text(L10n.format("はじめから %@ ↗", signed(gain)))
                            .font(ReelTheme.sans(12, weight: .semibold))
                            .foregroundColor(ReelTheme.accentDeep)
                    }
                }
                Chart {
                    ForEach(points) { result in
                        LineMark(x: .value("date", result.date), y: .value("score", result.score ?? 0))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(ReelTheme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        PointMark(x: .value("date", result.date), y: .value("score", result.score ?? 0))
                            .foregroundStyle(result.id == points.last?.id ? ReelTheme.accentDeep : ReelTheme.accent)
                            .symbolSize(result.id == points.last?.id ? 70 : 40)
                    }
                    if let target = goal?.targetScore {
                        RuleMark(y: .value("goal", target))
                            .foregroundStyle(ReelTheme.accentDeep.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text(L10n.format("目標 %d", target))
                                    .font(ReelTheme.sans(10))
                                    .foregroundColor(ReelTheme.accentDeep)
                            }
                    }
                }
                .chartYScale(domain: yDomain(points))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                            .font(ReelTheme.sans(9))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(ReelTheme.line)
                        AxisValueLabel().font(ReelTheme.sans(9))
                    }
                }
                .frame(height: 150)
            }
        }
        .padding(.top, 10)
    }

    private func yDomain(_ points: [PastPaperResult]) -> ClosedRange<Int> {
        let values = points.compactMap(\.score) + [goal?.targetScore].compactMap { $0 }
        guard let low = values.min(), let high = values.max() else { return 0...100 }
        let pad = max((high - low) / 5, 10)
        return max(low - pad, 0)...(high + pad)
    }

    private func seriesCard(_ item: PaperSeries) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.name)
                    .font(ReelTheme.sans(14))
                    .foregroundColor(ReelTheme.ink)
                    .lineLimit(1)
                Spacer()
                Text(L10n.format("%d回解いた", item.results.count))
                    .font(ReelTheme.sans(11))
                    .foregroundColor(ReelTheme.secondary)
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(item.results.suffix(4).enumerated()), id: \.element.id) { index, result in
                    if index > 0 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(ReelTheme.line)
                            .padding(.bottom, 16)
                    }
                    Button {
                        editing = result
                    } label: {
                        VStack(spacing: 2) {
                            Text(scoreText(result))
                                .font(ReelTheme.serif(18))
                                .foregroundColor(result.id == item.latest?.id ? ReelTheme.accentDeep : ReelTheme.ink)
                                .monospacedDigit()
                            Text(takeText(result, in: item))
                                .font(ReelTheme.sans(10))
                                .foregroundColor(ReelTheme.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                if let gain = item.gain {
                    Text(signed(gain))
                        .font(ReelTheme.sans(12, weight: .semibold))
                        .foregroundColor(ReelTheme.accentDeep)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Capsule().fill(ReelTheme.accentSoft))
                        .padding(.bottom, 14)
                }
            }
            Button {
                addingPaper = item.name
                showAdd = true
            } label: {
                Label(L10n.string("もう一度解いた"), systemImage: "plus")
                    .font(ReelTheme.sans(11, weight: .medium))
                    .foregroundColor(ReelTheme.accentDeep)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: ReelTheme.ink.opacity(0.06), radius: 10, y: 6)
        )
    }

    private func dateRow(_ result: PastPaperResult) -> some View {
        Button {
            editing = result
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.paperName)
                        .font(ReelTheme.sans(14))
                        .foregroundColor(ReelTheme.ink)
                    Text(result.date.formatted(.dateTime.month().day()))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                }
                Spacer()
                Text(scoreText(result))
                    .font(ReelTheme.serif(20))
                    .foregroundColor(ReelTheme.ink)
                    .monospacedDigit()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
        }
        .buttonStyle(.plain)
    }

    private func scoreText(_ result: PastPaperResult) -> String {
        if let score = result.score { return String(score) }
        switch result.outcome {
        case .passed: return L10n.string("合格")
        case .failed: return L10n.string("不合格")
        case .none: return "—"
        }
    }

    private func takeText(_ result: PastPaperResult, in item: PaperSeries) -> String {
        let number = (item.results.firstIndex { $0.id == result.id } ?? 0) + 1
        return L10n.format("%d回目 %@", number, result.date.formatted(.dateTime.month(.defaultDigits).day()))
    }
}

enum PaperOrder: String, CaseIterable, Identifiable {
    case byPaper
    case byDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .byPaper: return L10n.string("問題ごと")
        case .byDate: return L10n.string("日付順")
        }
    }
}

func signed(_ value: Int) -> String {
    value > 0 ? "+\(value)" : "\(value)"
}
