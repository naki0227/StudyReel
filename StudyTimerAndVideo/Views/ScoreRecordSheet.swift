import SwiftData
import SwiftUI

// 過去問・模試の点数を記録する。同じ問題の2回目以降は、前回の満点と大問をそのまま出す
struct ScoreRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PastPaperResult.date) private var results: [PastPaperResult]
    @Query(filter: #Predicate<StudyGoal> { $0.archivedAt == nil }, sort: \StudyGoal.createdAt, order: .reverse)
    private var goals: [StudyGoal]

    let result: PastPaperResult?

    @State private var paperName: String
    @State private var date = Date()
    @State private var hasDuration = false
    @State private var duration: TimeInterval = 2 * 3600
    @State private var score = ""
    @State private var maxScore = ""
    @State private var outcome: PaperOutcome = .none
    @State private var parts: [ScorePart] = []
    @State private var memo = ""
    @State private var showDelete = false
    @State private var loaded = false

    init(result: PastPaperResult?, paperName: String?) {
        self.result = result
        _paperName = State(initialValue: paperName ?? "")
    }

    private var trimmedName: String {
        paperName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // この回より前の、同じ問題の回
    private var previous: [PastPaperResult] {
        results.filter { $0.paperName == trimmedName && $0.id != result?.id && $0.date <= (result?.date ?? .distantFuture) }
    }

    private var takeNumber: Int { previous.count + 1 }

    private var knownPapers: [String] {
        PaperSeries.group(results).map(\.name)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && (Int(score) != nil || outcome != .none)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("問題"))
                                .font(ReelTheme.sans(11))
                                .foregroundColor(ReelTheme.secondary)
                            TextField(L10n.string("例：公式問題集10 Test 1"), text: $paperName)
                                .font(ReelTheme.sans(16))
                                .accessibilityIdentifier("score.paper")
                                .onChange(of: paperName) { fillFromPrevious() }
                            if result == nil, !knownPapers.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(knownPapers.prefix(8), id: \.self) { name in
                                            Button {
                                                paperName = name
                                            } label: {
                                                Text(name)
                                                    .font(ReelTheme.sans(11))
                                                    .lineLimit(1)
                                                    .foregroundColor(name == trimmedName ? ReelTheme.accentDeep : ReelTheme.secondary)
                                                    .padding(.horizontal, 10)
                                                    .frame(height: 26)
                                                    .background(Capsule().fill(name == trimmedName ? ReelTheme.accentSoft : ReelTheme.background))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .accessibilityIdentifier("record.paper.chips")
                            }
                        }
                        .padding(16)
                        divider
                        row(L10n.string("回数")) {
                            Text(previous.last.map { L10n.format("%d回目（前回 %@）", takeNumber, scoreText($0)) } ?? L10n.format("%d回目", takeNumber))
                                .font(ReelTheme.sans(13))
                                .foregroundColor(ReelTheme.secondary)
                        }
                        divider
                        row(L10n.string("日付")) {
                            DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date).labelsHidden()
                        }
                        divider
                        row(L10n.string("かかった時間")) {
                            if hasDuration {
                                DatePicker("", selection: durationBinding, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .environment(\.locale, Locale(identifier: "en_GB"))
                            } else {
                                Button(L10n.string("入れる")) { hasDuration = true }
                                    .font(ReelTheme.sans(13))
                            }
                        }
                    }

                    TapedPaper(tape: GoalTheme.tapeBlue, tapeAlignment: .topLeading, tapeAngle: -5) {
                        VStack(spacing: 12) {
                            HStack {
                                GoalScript(text: ordinal(takeNumber) + " try ✦", size: 14)
                                Spacer()
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                TextField(previous.last?.score.map(String.init) ?? "0", text: $score)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(ReelTheme.serif(52))
                                    .foregroundColor(ReelTheme.ink)
                                    .frame(maxWidth: 170)
                                    .accessibilityIdentifier("score.value")
                                Text("/")
                                    .font(ReelTheme.serif(22))
                                    .foregroundColor(ReelTheme.secondary)
                                TextField("990", text: $maxScore)
                                    .keyboardType(.numberPad)
                                    .font(ReelTheme.serif(22))
                                    .foregroundColor(ReelTheme.secondary)
                                    .frame(width: 70)
                                    .accessibilityIdentifier("score.max")
                            }
                            if let summary = scoreSummary {
                                Text(summary)
                                    .font(ReelTheme.sans(12))
                                    .foregroundColor(ReelTheme.secondary)
                            }
                            Picker("", selection: $outcome) {
                                Text(L10n.string("点数のみ")).tag(PaperOutcome.none)
                                Text(L10n.string("合格")).tag(PaperOutcome.passed)
                                Text(L10n.string("不合格")).tag(PaperOutcome.failed)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(.top, 6)

                    card {
                        ForEach($parts) { $part in
                            HStack(spacing: 8) {
                                TextField(L10n.string("大問の名前"), text: $part.name)
                                    .font(ReelTheme.sans(14))
                                Spacer()
                                partField("0", value: $part.score)
                                Text("/").foregroundColor(ReelTheme.secondary)
                                partField("100", value: $part.maxScore)
                                Button {
                                    parts.removeAll { $0.id == part.id }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(ReelTheme.secondary)
                                }
                                .accessibilityLabel(L10n.string("削除"))
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 50)
                            divider
                        }
                        Button {
                            parts.append(ScorePart(name: ""))
                        } label: {
                            Label(L10n.string("大問を足す"), systemImage: "plus")
                                .font(ReelTheme.sans(13))
                                .foregroundColor(ReelTheme.accentDeep)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                    }

                    card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.string("ひとこと"))
                                .font(ReelTheme.sans(11))
                                .foregroundColor(ReelTheme.secondary)
                            TextField(L10n.string("例：Part 7 で時間切れ"), text: $memo, axis: .vertical)
                                .font(ReelTheme.sans(14))
                                .lineLimit(1...4)
                        }
                        .padding(16)
                    }

                    Text(L10n.string("大問は1回入れると、同じ問題の次の回から同じ形で出ます。合否のある試験は「合格・不合格」で残せます。"))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                        .padding(.horizontal, 4)

                    if result != nil {
                        Button(L10n.string("この記録を消す"), role: .destructive) { showDelete = true }
                            .font(ReelTheme.sans(13))
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(GridPaperBackground().ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                // 数字キーボードには閉じるキーがないので「完了」を出す
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.string("完了")) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .font(ReelTheme.sans(15, weight: .semibold))
                }
            }
            .navigationTitle(L10n.string("点数を記録"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("キャンセル")) { dismiss() }
                        .foregroundColor(ReelTheme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("保存"), action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("score.save")
                }
            }
            .onAppear(perform: load)
            .confirmationDialog(L10n.string("この記録を消しますか？"), isPresented: $showDelete, titleVisibility: .visible) {
                Button(L10n.string("消す"), role: .destructive) {
                    if let result { modelContext.delete(result) }
                    try? modelContext.save()
                    CloudBackup.markChanged()
                    dismiss()
                }
            }
        }
        .tint(ReelTheme.accentDeep)
    }

    private var scoreSummary: String? {
        guard let value = Int(score) else { return nil }
        var pieces: [String] = []
        if let max = Int(maxScore), max > 0 {
            pieces.append("\(Int((Double(value) / Double(max) * 100).rounded()))%")
        }
        if let last = previous.last?.score {
            pieces.append(L10n.format("前回から %@", signed(value - last)))
        }
        return pieces.isEmpty ? nil : pieces.joined(separator: " ・ ")
    }

    private var durationBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(duration) },
            set: { duration = $0.timeIntervalSince(Calendar.current.startOfDay(for: $0)) }
        )
    }

    private var divider: some View {
        Rectangle().fill(ReelTheme.line).frame(height: 1).padding(.leading, 16)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: ReelTheme.ink.opacity(0.06), radius: 10, y: 6)
            )
    }

    private func row<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(title)
                .font(ReelTheme.sans(14))
                .foregroundColor(ReelTheme.ink)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }

    private func partField(_ placeholder: String, value: Binding<Int?>) -> some View {
        TextField(placeholder, text: Binding(
            get: { value.wrappedValue.map(String.init) ?? "" },
            set: { value.wrappedValue = Int($0) }
        ))
        .keyboardType(.numberPad)
        .multilineTextAlignment(.center)
        .font(ReelTheme.sans(14))
        .frame(width: 52, height: 30)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(ReelTheme.background))
    }

    private func scoreText(_ item: PastPaperResult) -> String {
        if let value = item.score { return L10n.format("%d点", value) }
        return item.outcome == .passed ? L10n.string("合格") : item.outcome == .failed ? L10n.string("不合格") : "—"
    }

    private func ordinal(_ number: Int) -> String {
        switch number {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(number)th"
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let result else {
            fillFromPrevious()
            return
        }
        paperName = result.paperName
        date = result.date
        score = result.score.map(String.init) ?? ""
        maxScore = result.maxScore.map(String.init) ?? ""
        outcome = result.outcome
        parts = result.parts
        memo = result.memo
        if let seconds = result.durationSeconds {
            hasDuration = true
            duration = TimeInterval(seconds)
        }
    }

    // 新しく記録するとき、同じ問題の前回から満点と大問の形を引き継ぐ。初めての問題なら、目標の満点を入れておく
    // （満点の欄が薄い見本の「990」のままだと、入れたつもりで空のまま保存されて、目標の点数に数えられなかった）
    private func fillFromPrevious() {
        guard result == nil else { return }
        guard let last = previous.last else {
            if maxScore.isEmpty, let max = goals.first?.maxScore { maxScore = String(max) }
            return
        }
        if maxScore.isEmpty { maxScore = last.maxScore.map(String.init) ?? "" }
        if parts.isEmpty { parts = last.parts.map { ScorePart(name: $0.name, maxScore: $0.maxScore) } }
    }

    private func save() {
        guard canSave else { return }
        let cleanedParts = parts.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        let target = result ?? PastPaperResult(paperName: trimmedName)
        target.paperName = trimmedName
        target.date = date
        target.score = Int(score)
        target.maxScore = Int(maxScore)
        target.outcome = outcome
        target.durationSeconds = hasDuration ? Int(duration) : nil
        target.parts = cleanedParts
        target.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        if result == nil { modelContext.insert(target) }
        try? modelContext.save()
        CloudBackup.markChanged()
        dismiss()
    }
}
