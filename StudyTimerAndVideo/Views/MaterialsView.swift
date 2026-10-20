import SwiftData
import SwiftUI

// 記録の集まりから、合計時間・日数・回数を出す
struct StudyTotals {
    let seconds: Int
    let days: Int
    let count: Int
    let firstDate: Date?
    let lastDate: Date?

    init(sessions: [StudySession], calendar: Calendar = .current) {
        seconds = sessions.reduce(0) { $0 + $1.duration }
        days = Set(sessions.map { calendar.startOfDay(for: $0.date) }).count
        count = sessions.count
        firstDate = sessions.map(\.date).min()
        lastDate = sessions.map(\.date).max()
    }

    var detailText: String {
        L10n.format("%@ · %d日 · %d回", WeeklyVlogMaker.durationText(seconds), days, count)
    }
}

// 教材の一覧。勉強中とやり終えたに分けて、それぞれの合計を出す
struct MaterialsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudyMaterial.createdAt, order: .reverse) private var materials: [StudyMaterial]
    @Query(sort: \StudySession.date) private var sessions: [StudySession]

    @State private var showAdd = false

    private var studying: [StudyMaterial] { materials.filter { !$0.isFinished } }
    private var finished: [StudyMaterial] {
        materials.filter(\.isFinished).sorted { ($0.finishedAt ?? .distantPast) > ($1.finishedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if materials.isEmpty {
                        emptyState
                    } else {
                        if !studying.isEmpty {
                            section(L10n.string("勉強中"), items: studying)
                        }
                        if !finished.isEmpty {
                            section(L10n.string("やり終えた"), items: finished)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(ReelTheme.background.ignoresSafeArea())
            // 見出しは左上に置くと iOS 26 で「…」にまとめられるので、上の真ん中に出す
            .navigationTitle(L10n.string("教材"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showAdd = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(L10n.string("教材を追加"))
                        Button(L10n.string("閉じる")) { dismiss() }
                    }
                    .foregroundColor(ReelTheme.accentDeep)
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let material = materials.first(where: { $0.id == id }) {
                    MaterialDetailView(material: material)
                }
            }
            .sheet(isPresented: $showAdd) {
                MaterialAddView { _ in
                    showAdd = false
                }
            }
        }
        .tint(ReelTheme.accentDeep)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(ReelTheme.accentDeep)
            Text(L10n.string("まだ教材がありません"))
                .font(ReelTheme.serif(20))
                .foregroundColor(ReelTheme.ink)
            Text(L10n.string("使っている参考書や問題集を入れると、教材ごとに勉強時間がたまります。"))
                .font(ReelTheme.sans(13))
                .foregroundColor(ReelTheme.secondary)
                .multilineTextAlignment(.center)
            Button {
                showAdd = true
            } label: {
                Text(L10n.string("教材を追加"))
                    .font(ReelTheme.sans(15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(ReelTheme.accentDeep))
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func section(_ title: String, items: [StudyMaterial]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ReelTheme.sans(12))
                .foregroundColor(ReelTheme.secondary)
                .padding(.leading, 4)
            ReelCard {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, material in
                        if index > 0 {
                            Divider().padding(.leading, 70)
                        }
                        NavigationLink(value: material.id) {
                            row(material)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func row(_ material: StudyMaterial) -> some View {
        let totals = StudyTotals(sessions: sessions.filter { $0.materialID == material.id })
        return HStack(spacing: 14) {
            MaterialCover(material: material, cornerRadius: 4)
                .frame(width: 40, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text(material.name)
                    .font(ReelTheme.sans(15))
                    .foregroundColor(ReelTheme.ink)
                    .lineLimit(2)
                Text(material.subject)
                    .font(ReelTheme.sans(11))
                    .foregroundColor(ReelTheme.secondary)
                Text(totals.detailText)
                    .font(ReelTheme.sans(12))
                    .foregroundColor(ReelTheme.accentDeep)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ReelTheme.line)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// 教材ひとつの詳細。やり終えたら、そのまま共有カードを出す
struct MaterialDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudySession.date, order: .reverse) private var allSessions: [StudySession]
    @StateObject private var subjectManager = SubjectManager()

    @Bindable var material: StudyMaterial

    @State private var showShare = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    private var sessions: [StudySession] {
        allSessions.filter { $0.materialID == material.id }
    }

    private var totals: StudyTotals { StudyTotals(sessions: sessions) }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                totalsCard
                weekBars
                actions
                recentList
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(ReelTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label(L10n.string("編集"), systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label(L10n.string("削除"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showShare) {
            StudyShareView(initialMaterial: material)
        }
        .sheet(isPresented: $showEdit) {
            MaterialEditView(material: material, subjects: subjectManager.subjects)
        }
        .alert(L10n.string("この教材を削除しますか？"), isPresented: $showDeleteConfirm) {
            Button(L10n.string("キャンセル"), role: .cancel) {}
            Button(L10n.string("削除"), role: .destructive) {
                deleteMaterial()
            }
        } message: {
            Text(L10n.string("勉強の記録は消えずに残ります。"))
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            MaterialCover(material: material, cornerRadius: 8)
                .frame(width: 120, height: 162)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            if material.isFinished {
                Text(L10n.string("やり終えた！"))
                    .font(ReelTheme.sans(12, weight: .semibold))
                    .foregroundColor(ReelTheme.accentDeep)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(ReelTheme.accentSoft))
            }
            Text(material.name)
                .font(ReelTheme.serif(24))
                .foregroundColor(ReelTheme.ink)
                .multilineTextAlignment(.center)
            Text([material.subject, material.author].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                .font(ReelTheme.sans(12))
                .foregroundColor(ReelTheme.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var totalsCard: some View {
        ReelCard {
            VStack(spacing: 14) {
                HStack {
                    stat(L10n.string("合計時間"), WeeklyVlogMaker.durationText(totals.seconds))
                    stat(L10n.string("日数"), L10n.format("%d日", totals.days))
                    stat(L10n.string("回数"), L10n.format("%d回", totals.count))
                }
                Divider()
                HStack(spacing: 8) {
                    Text(L10n.string("始めた日"))
                        .foregroundColor(ReelTheme.secondary)
                    Text(dateText(totals.firstDate ?? material.createdAt))
                        .foregroundColor(ReelTheme.ink)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(ReelTheme.secondary)
                    if let finishedAt = material.finishedAt {
                        Text(dateText(finishedAt))
                            .foregroundColor(ReelTheme.ink)
                    } else {
                        Text(L10n.string("勉強中"))
                            .foregroundColor(ReelTheme.accentDeep)
                    }
                }
                .font(ReelTheme.sans(13))
            }
            .padding(16)
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(ReelTheme.serif(20))
                .foregroundColor(ReelTheme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // 直近8週の勉強時間
    private var weekBars: some View {
        let calendar = Calendar.current
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
        let weeks: [(Date, Int)] = (0..<8).reversed().map { back in
            let start = calendar.date(byAdding: .weekOfYear, value: -back, to: thisWeek) ?? thisWeek
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            let seconds = sessions.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.duration }
            return (start, seconds)
        }
        let peak = max(weeks.map(\.1).max() ?? 0, 1)
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("Md")

        return VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("週ごとの勉強時間"))
                .font(ReelTheme.sans(13))
                .foregroundColor(ReelTheme.ink)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            Capsule().fill(ReelTheme.line).frame(height: 64)
                            Capsule()
                                .fill(week.1 > 0 ? ReelTheme.accent : Color.clear)
                                .frame(height: max(week.1 > 0 ? 5 : 0, 64 * CGFloat(week.1) / CGFloat(peak)))
                        }
                        .frame(width: 12)
                        Text(index % 2 == 1 ? formatter.string(from: week.0) : " ")
                            .font(ReelTheme.sans(9))
                            .foregroundColor(ReelTheme.secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if material.isFinished {
                Button {
                    showShare = true
                } label: {
                    primaryLabel(L10n.string("共有する"), systemImage: "square.and.arrow.up")
                }
                Button {
                    material.finishedAt = nil
                } label: {
                    secondaryLabel(L10n.string("まだ続ける"))
                }
            } else {
                Button {
                    material.finishedAt = Date()
                    showShare = true
                } label: {
                    primaryLabel(L10n.string("やり終えた"), systemImage: "checkmark")
                }
                Button {
                    showShare = true
                } label: {
                    secondaryLabel(L10n.string("共有する"))
                }
            }
        }
    }

    private func primaryLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(ReelTheme.sans(15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Capsule().fill(ReelTheme.accentDeep))
    }

    private func secondaryLabel(_ title: String) -> some View {
        Text(title)
            .font(ReelTheme.sans(14, weight: .medium))
            .foregroundColor(ReelTheme.accentDeep)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(Capsule().fill(ReelTheme.accentSoft))
    }

    @ViewBuilder
    private var recentList: some View {
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("最近の記録"))
                    .font(ReelTheme.sans(13))
                    .foregroundColor(ReelTheme.ink)
                ReelCard {
                    VStack(spacing: 0) {
                        ForEach(Array(sessions.prefix(10).enumerated()), id: \.element.id) { index, session in
                            if index > 0 {
                                Divider().padding(.leading, 16)
                            }
                            HStack {
                                Text(dateText(session.date))
                                    .foregroundColor(ReelTheme.ink)
                                Text(session.displayTitle)
                                    .foregroundColor(ReelTheme.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Text(WeeklyVlogMaker.durationText(session.duration))
                                    .foregroundColor(ReelTheme.secondary)
                                    .monospacedDigit()
                            }
                            .font(ReelTheme.sans(13))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                        }
                    }
                }
            }
        }
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    // 教材だけ消して、記録は教材なしとして残す
    private func deleteMaterial() {
        for session in sessions {
            session.materialID = nil
        }
        MediaStore.delete(material.coverFileName)
        modelContext.delete(material)
        dismiss()
    }
}

// 教材の名前と教科を直す
struct MaterialEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var material: StudyMaterial
    let subjects: [String]

    @State private var name = ""
    @State private var subject = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.string("教材名")) {
                    TextField(L10n.string("教材名"), text: $name)
                }
                Section(L10n.string("教科")) {
                    Picker(L10n.string("教科"), selection: $subject) {
                        ForEach(subjectOptions, id: \.self) { item in
                            Text(item).tag(item)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ReelTheme.background.ignoresSafeArea())
            .navigationTitle(L10n.string("教材を編集"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("キャンセル")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("保存")) {
                        material.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        material.subject = subject
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                name = material.name
                subject = material.subject
            }
        }
        .tint(ReelTheme.accentDeep)
    }

    private var subjectOptions: [String] {
        subjects.contains(material.subject) || material.subject.isEmpty ? subjects : [material.subject] + subjects
    }
}
