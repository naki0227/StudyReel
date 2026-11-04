import SwiftData
import SwiftUI
import UIKit

// 勉強の記録を CSV と PDF で書き出す（Pro）。資格の学習記録や、塾・家族に見せる用
struct StudyExportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeKit: StoreKitManager
    @Query(sort: \StudySession.date) private var sessions: [StudySession]
    @Query private var materials: [StudyMaterial]

    @State private var range: ExportRange = .thisMonth
    @State private var csvURL: URL?
    @State private var pdfURL: URL?
    @State private var showPaywall = false

    private var picked: [StudySession] {
        guard let interval = range.interval() else { return sessions }
        return sessions.filter { interval.contains($0.date) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(L10n.string("期間"), selection: $range) {
                        ForEach(ExportRange.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text(L10n.format("%d件の記録", picked.count))
                        Spacer()
                        Text(StudyExport.durationText(picked.reduce(0) { $0 + $1.duration }))
                            .monospacedDigit()
                    }
                    .font(ReelTheme.sans(14))
                } footer: {
                    Text(L10n.string("日付・開始時刻・勉強時間・教科・タイトル・教材・机にいた時間・メモを書き出します。"))
                }

                Section {
                    if storeKit.isProUnlocked {
                        if let csvURL {
                            ShareLink(item: csvURL) {
                                Label(L10n.string("CSV で書き出す（表計算ソフト用）"), systemImage: "tablecells")
                            }
                        }
                        if let pdfURL {
                            ShareLink(item: pdfURL) {
                                Label(L10n.string("PDF で書き出す（印刷・提出用）"), systemImage: "doc.richtext")
                            }
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            Label(L10n.string("書き出しは Pro で使えます"), systemImage: "lock.fill")
                        }
                    }
                }
            }
            .navigationTitle(L10n.string("記録を書き出す"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("閉じる")) { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .onAppear(perform: build)
            .onChange(of: range) { build() }
        }
    }

    private func build() {
        let names = Dictionary(materials.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let rows = picked.map { StudyExport.Row(session: $0, materialName: $0.materialID.flatMap { names[$0] }) }
        csvURL = StudyExport.writeCSV(rows)
        pdfURL = StudyExport.writePDF(rows, title: range.title)
    }
}

enum ExportRange: String, CaseIterable, Identifiable {
    case thisMonth, lastMonth, thisYear, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thisMonth: return L10n.string("今月")
        case .lastMonth: return L10n.string("先月")
        case .thisYear: return L10n.string("今年")
        case .all: return L10n.string("すべて")
        }
    }

    func interval(calendar: Calendar = .current, now: Date = Date()) -> DateInterval? {
        switch self {
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: now)
        case .lastMonth:
            guard let month = calendar.dateInterval(of: .month, for: now),
                  let start = calendar.date(byAdding: .month, value: -1, to: month.start) else { return nil }
            return DateInterval(start: start, end: month.start)
        case .thisYear:
            return calendar.dateInterval(of: .year, for: now)
        case .all:
            return nil
        }
    }
}

enum StudyExport {
    struct Row {
        let date: Date
        let minutes: Int
        let subject: String
        let title: String
        let material: String
        let focusMinutes: Int?
        let memo: String

        init(session: StudySession, materialName: String?) {
            date = session.date
            minutes = session.duration / 60
            subject = session.subject
            title = session.title ?? ""
            material = materialName ?? ""
            focusMinutes = session.awaySeconds.map { max(0, session.duration - $0) / 60 }
            memo = session.memo ?? ""
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func durationText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes < 60 { return L10n.format("%d分", minutes) }
        return minutes % 60 == 0 ? L10n.format("%d時間", minutes / 60) : L10n.format("%d時間%d分", minutes / 60, minutes % 60)
    }

    private static func file(_ ext: String) -> URL {
        let day = dayFormatter.string(from: Date())
        return FileManager.default.temporaryDirectory.appendingPathComponent("StudyReel-\(day).\(ext)")
    }

    // Excel で文字化けしないよう、先頭に BOM を付けた UTF-8 にする
    static func writeCSV(_ rows: [Row]) -> URL? {
        func cell(_ value: String) -> String {
            "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        var lines = [[
            L10n.string("日付"), L10n.string("開始"), L10n.string("勉強時間（分）"), L10n.string("教科"),
            L10n.string("タイトル"), L10n.string("教材"), L10n.string("机にいた時間（分）"), L10n.string("メモ")
        ].map(cell).joined(separator: ",")]
        for row in rows {
            lines.append([
                dayFormatter.string(from: row.date), timeFormatter.string(from: row.date), String(row.minutes), row.subject,
                row.title, row.material, row.focusMinutes.map(String.init) ?? "", row.memo
            ].map(cell).joined(separator: ","))
        }
        let url = file("csv")
        let data = Data([0xEF, 0xBB, 0xBF]) + Data(lines.joined(separator: "\r\n").utf8)
        return (try? data.write(to: url)) == nil ? nil : url
    }

    // A4 縦。上に期間と合計、そのあとに1行1記録の表。入りきらなければ次のページへ
    static func writePDF(_ rows: [Row], title: String) -> URL? {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 40
        let url = file("pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let sub = UIColor(white: 0.45, alpha: 1)
        func draw(_ text: String, at point: CGPoint, size: CGFloat, color: UIColor = UIColor(white: 0.15, alpha: 1), weight: UIFont.Weight = .regular, width: CGFloat = 200) {
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
            (text as NSString).draw(with: CGRect(x: point.x, y: point.y, width: width, height: size * 1.4),
                                    options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes, context: nil)
        }
        let columns: [(String, CGFloat)] = [
            (L10n.string("日付"), 70), (L10n.string("開始"), 40), (L10n.string("分"), 36),
            (L10n.string("教科"), 80), (L10n.string("タイトル・教材"), 210), (L10n.string("机にいた"), 79)
        ]
        do {
            try renderer.writePDF(to: url) { context in
                var y = page.height
                func header() {
                    var x = margin
                    for (name, width) in columns {
                        draw(name, at: CGPoint(x: x, y: y), size: 9, color: sub, weight: .semibold, width: width)
                        x += width
                    }
                    y += 18
                }
                for (index, row) in rows.enumerated() {
                    if y > page.height - margin - 16 {
                        context.beginPage()
                        y = margin
                        if index == 0 {
                            draw(L10n.string("StudyReel 勉強の記録"), at: CGPoint(x: margin, y: y), size: 18, weight: .semibold, width: 400)
                            y += 28
                            let total = rows.reduce(0) { $0 + $1.minutes * 60 }
                            let days = Set(rows.map { dayFormatter.string(from: $0.date) }).count
                            draw(L10n.format("%@・合計 %@・%d日・%d件", title, durationText(total), days, rows.count),
                                 at: CGPoint(x: margin, y: y), size: 11, color: sub, width: 500)
                            y += 28
                        }
                        header()
                    }
                    let values = [
                        dayFormatter.string(from: row.date), timeFormatter.string(from: row.date), String(row.minutes), row.subject,
                        [row.title, row.material].filter { !$0.isEmpty }.joined(separator: " / "),
                        row.focusMinutes.map { L10n.format("%d分", $0) } ?? "—"
                    ]
                    var x = margin
                    for (value, column) in zip(values, columns) {
                        draw(value, at: CGPoint(x: x, y: y), size: 9, width: column.1 - 4)
                        x += column.1
                    }
                    y += 15
                }
                if rows.isEmpty {
                    context.beginPage()
                    draw(L10n.string("StudyReel 勉強の記録"), at: CGPoint(x: margin, y: margin), size: 18, weight: .semibold, width: 400)
                    draw(L10n.string("この期間の記録はありません。"), at: CGPoint(x: margin, y: margin + 36), size: 11, color: sub, width: 400)
                }
            }
            return url
        } catch {
            return nil
        }
    }
}
