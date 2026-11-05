import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// ほかのアプリの記録（CSV）を取り込む。乗り換えても、これまでの記録が1年の草とグラフに残る
struct StudyImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [StudySession]
    @ObservedObject var subjectManager: SubjectManager

    @State private var showPicker = false
    @State private var parsed: StudyImport.Result?
    @State private var newRows: [StudyImport.Row] = []
    @State private var message: String?
    @State private var imported = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showPicker = true
                    } label: {
                        Label(L10n.string("CSV ファイルを選ぶ"), systemImage: "doc.badge.plus")
                    }
                } footer: {
                    Text(L10n.string("ほかのアプリや表計算ソフトから書き出した CSV を読み込みます。1行目に「日付」と「勉強時間（分）」などの見出しがあれば読めます。教科・開始時刻・メモの列もあれば一緒に取り込みます。"))
                }

                if let message {
                    Section {
                        Text(message)
                            .font(ReelTheme.sans(14))
                            .foregroundColor(ReelTheme.secondary)
                    }
                }

                if let parsed, !imported {
                    Section {
                        HStack {
                            Text(L10n.format("%d件の記録", newRows.count))
                            Spacer()
                            Text(StudyExport.durationText(newRows.reduce(0) { $0 + $1.seconds }))
                                .monospacedDigit()
                        }
                        if let first = newRows.map(\.date).min(), let last = newRows.map(\.date).max() {
                            Text("\(first.formatted(date: .abbreviated, time: .omitted)) – \(last.formatted(date: .abbreviated, time: .omitted))")
                                .font(ReelTheme.sans(13))
                                .foregroundColor(ReelTheme.secondary)
                        }
                        Button {
                            importRows()
                        } label: {
                            Text(L10n.string("取り込む"))
                                .font(ReelTheme.sans(15, weight: .semibold))
                        }
                        .disabled(newRows.isEmpty)
                    } footer: {
                        let duplicates = parsed.rows.count - newRows.count
                        Text(L10n.format("読めなかった行：%d件　すでにある記録：%d件（取り込みません）", parsed.skipped, duplicates))
                    }
                    if !newRows.isEmpty {
                        Section(L10n.string("はじめの5件")) {
                            ForEach(Array(newRows.prefix(5).enumerated()), id: \.offset) { _, row in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.subject.isEmpty ? fallbackSubject : row.subject)
                                            .font(ReelTheme.sans(14))
                                        Text(row.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(ReelTheme.sans(11))
                                            .foregroundColor(ReelTheme.secondary)
                                    }
                                    Spacer()
                                    Text(StudyExport.durationText(row.seconds))
                                        .font(ReelTheme.sans(13))
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.string("ほかのアプリの記録を取り込む"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("閉じる")) { dismiss() }
                }
            }
            .fileImporter(isPresented: $showPicker, allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .text]) { result in
                switch result {
                case let .success(url): read(url)
                case .failure: message = L10n.string("ファイルを開けませんでした。")
                }
            }
        }
    }

    private var fallbackSubject: String {
        subjectManager.subjects.first ?? L10n.string("その他")
    }

    private func read(_ url: URL) {
        imported = false
        parsed = nil
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            message = L10n.string("ファイルを開けませんでした。")
            return
        }
        // Excel で保存した日本語の CSV は Shift_JIS のことがある
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .shiftJIS) ?? String(data: data, encoding: .utf16) else {
            message = L10n.string("文字コードが読めませんでした。UTF-8 で保存し直してください。")
            return
        }
        switch StudyImport.parse(text) {
        case let .success(result):
            parsed = result
            newRows = result.rows.filter { !alreadyExists($0) }
            message = result.rows.isEmpty ? L10n.string("取り込める記録が見つかりませんでした。") : nil
        case .failure(.empty):
            message = L10n.string("記録が入っていないファイルでした。")
        case .failure(.noColumns):
            message = L10n.string("「日付」と「勉強時間」の列が見つかりませんでした。1行目に見出しがあるか確かめてください。")
        }
    }

    // 同じ時刻（分まで）で同じ長さの記録があれば、取り込み済みとみなす
    private func alreadyExists(_ row: StudyImport.Row) -> Bool {
        let minute = Int(row.date.timeIntervalSince1970 / 60)
        return sessions.contains { Int($0.date.timeIntervalSince1970 / 60) == minute && abs($0.duration - row.seconds) < 60 }
    }

    private func importRows() {
        for row in newRows {
            let subject = row.subject.isEmpty ? fallbackSubject : row.subject
            subjectManager.add(subject)
            let session = StudySession(
                date: row.date,
                duration: row.seconds,
                subject: subject,
                recordedAt: Date(),
                title: row.title.isEmpty ? nil : row.title,
                memo: row.memo.isEmpty ? nil : row.memo
            )
            modelContext.insert(session)
        }
        try? modelContext.save()
        CloudBackup.markChanged()
        message = L10n.format("%d件の記録を取り込みました。", newRows.count)
        imported = true
        newRows = []
    }
}
