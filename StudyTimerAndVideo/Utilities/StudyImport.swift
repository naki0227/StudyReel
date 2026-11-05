import Foundation

// ほかのアプリ（Studyplus・YPT・表計算ソフトなど）から書き出した勉強の記録（CSV）を読む。
// 決まった形はないので、1行目の見出しから「日付・開始・時間・教科・メモ」の列を探す。
// StudyReel が書き出した CSV もそのまま読める
enum StudyImport {
    struct Row: Equatable {
        let date: Date
        let seconds: Int
        let subject: String
        let title: String
        let memo: String
    }

    struct Result {
        var rows: [Row]
        // 読めなかった行の数（日付か時間が分からない行）
        var skipped: Int
    }

    enum Failure: Error, Equatable {
        case empty
        // 日付か勉強時間の列が見つからない
        case noColumns
    }

    enum DurationUnit { case seconds, minutes, hours, guess }

    private struct Columns {
        var date: Int?
        var start: Int?
        var duration: Int?
        var unit: DurationUnit = .guess
        var end: Int?
        var subject: Int?
        var title: Int?
        var memo: Int?
    }

    static func parse(_ text: String, calendar: Calendar = .current) -> Swift.Result<Result, Failure> {
        let table = csvRows(text.replacingOccurrences(of: "\u{FEFF}", with: ""))
            .filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } }
        guard let header = table.first, table.count > 1 else { return .failure(.empty) }
        let columns = findColumns(header)
        guard columns.date != nil, columns.duration != nil || (columns.start != nil && columns.end != nil) else {
            return .failure(.noColumns)
        }
        var rows: [Row] = []
        var skipped = 0
        for cells in table.dropFirst() {
            func cell(_ index: Int?) -> String {
                guard let index, index < cells.count else { return "" }
                return cells[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard var date = parseDate(cell(columns.date), calendar: calendar) else { skipped += 1; continue }
            if let time = parseTime(cell(columns.start)) {
                date = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: date) ?? date
            }
            var seconds = parseDuration(cell(columns.duration), unit: columns.unit)
            if seconds == nil, let start = parseTime(cell(columns.start)), let end = parseTime(cell(columns.end)) {
                var minutes = (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute)
                if minutes < 0 { minutes += 24 * 60 }
                seconds = minutes * 60
            }
            // 0分や、1日より長いものは記録として扱わない
            guard let seconds, seconds >= 60, seconds <= 24 * 3600 else { skipped += 1; continue }
            rows.append(Row(date: date, seconds: seconds, subject: cell(columns.subject), title: cell(columns.title), memo: cell(columns.memo)))
        }
        return .success(Result(rows: rows, skipped: skipped))
    }

    // MARK: - 見出し

    private static func findColumns(_ header: [String]) -> Columns {
        var columns = Columns()
        for (index, raw) in header.enumerated() {
            let name = raw.lowercased().replacingOccurrences(of: " ", with: "")
            func has(_ words: [String]) -> Bool { words.contains { name.contains($0) } }
            if columns.date == nil, has(["日付", "date", "日にち", "記録日", "날짜", "日期"]) {
                columns.date = index
            } else if columns.start == nil, has(["開始", "start", "始め", "시작", "开始", "開始時刻"]) {
                columns.start = index
            } else if columns.end == nil, has(["終了", "end", "終わり", "종료", "结束", "結束"]) {
                columns.end = index
            } else if columns.duration == nil, has(["勉強時間", "学習時間", "時間", "duration", "minutes", "min", "time", "分", "秒", "seconds", "공부시간", "시간", "学习时间", "時長", "时长"]) {
                // 「机にいた時間」は勉強時間ではない
                if has(["机", "focus", "away"]) { continue }
                columns.duration = index
                if has(["秒", "sec"]) { columns.unit = .seconds }
                else if has(["分", "min"]) { columns.unit = .minutes }
                else if has(["hour", "（h）", "(h)"]) { columns.unit = .hours }
            } else if columns.subject == nil, has(["教科", "科目", "subject", "category", "カテゴリ", "과목", "科目"]) {
                columns.subject = index
            } else if columns.title == nil, has(["タイトル", "教材", "title", "material", "book", "제목", "教材"]) {
                columns.title = index
            } else if columns.memo == nil, has(["メモ", "memo", "note", "コメント", "comment", "메모", "备注", "備註"]) {
                columns.memo = index
            }
        }
        return columns
    }

    // MARK: - 値

    private static let dateFormats = [
        "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd",
        "yyyy/MM/dd HH:mm:ss", "yyyy/MM/dd HH:mm", "yyyy/MM/dd", "yyyy/M/d H:mm", "yyyy/M/d",
        "yyyy.MM.dd", "yyyy.M.d", "yyyy年M月d日 H:mm", "yyyy年M月d日", "MM/dd/yyyy", "M/d/yyyy",
    ]

    static func parseDate(_ text: String, calendar: Calendar = .current) -> Date? {
        guard !text.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = calendar.timeZone
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    static func parseTime(_ text: String) -> (hour: Int, minute: Int)? {
        let parts = text.split(separator: ":").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count >= 2, (0..<48).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return (parts[0] % 24, parts[1])
    }

    // 「90」「1:30」「1:30:00」「1時間30分」「90分」「1.5h」「45min」などを秒にする
    static func parseDuration(_ raw: String, unit: DurationUnit = .guess) -> Int? {
        let text = raw.lowercased().replacingOccurrences(of: " ", with: "")
        guard !text.isEmpty else { return nil }
        let colon = text.split(separator: ":").map(String.init)
        if colon.count >= 2, colon.allSatisfy({ Int($0) != nil }) {
            let numbers = colon.compactMap { Int($0) }
            return colon.count == 2 ? numbers[0] * 3600 + numbers[1] * 60 : numbers[0] * 3600 + numbers[1] * 60 + numbers[2]
        }
        var hours = 0.0, minutes = 0.0, seconds = 0.0
        var found = false
        let pattern = #"([0-9]+(?:\.[0-9]+)?)(時間|h|hr|hours?|시간|小时|小時|分|m|min|minutes?|분|分钟|分鐘|秒|s|sec|seconds?|초)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let valueRange = Range(match.range(at: 1), in: text), let unitRange = Range(match.range(at: 2), in: text),
                      let value = Double(text[valueRange]) else { continue }
                found = true
                switch String(text[unitRange]) {
                case "時間", "h", "hr", "hour", "hours", "시간", "小时", "小時": hours += value
                case "秒", "s", "sec", "second", "seconds", "초": seconds += value
                default: minutes += value
                }
            }
        }
        if found { return Int(hours * 3600 + minutes * 60 + seconds) }
        guard let value = Double(text) else { return nil }
        switch unit {
        case .seconds: return Int(value)
        case .minutes: return Int(value * 60)
        case .hours: return Int(value * 3600)
        // 単位が分からない数字は、小数なら時間、整数なら分とみなす
        case .guess: return text.contains(".") ? Int(value * 3600) : Int(value * 60)
        }
    }

    // MARK: - CSV

    // カンマ区切り（タブ区切りも可）。"" で囲んだ中のカンマ・改行・"" をそのまま読む
    static func csvRows(_ text: String) -> [[String]] {
        let firstLine = text.prefix { $0 != "\n" && $0 != "\r" }
        let separator: Character = firstLine.contains("\t") && !firstLine.contains(",") ? "\t" : ","
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var iterator = Array(text).makeIterator()
        var pending: Character?
        while let char = pending ?? iterator.next() {
            pending = nil
            if quoted {
                if char == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" { field.append("\"") } else { quoted = false; pending = next }
                    } else {
                        quoted = false
                    }
                } else {
                    field.append(char)
                }
                continue
            }
            switch char {
            case "\"": quoted = true
            case separator: row.append(field); field = ""
            case "\r\n", "\n", "\r":
                row.append(field); rows.append(row); row = []; field = ""
            default: field.append(char)
            }
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
}
