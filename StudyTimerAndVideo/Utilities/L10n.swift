import Foundation

enum L10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Locale.autoupdatingCurrent, arguments: arguments)
    }

    static var defaultSubjects: [String] {
        [
            string("数学"),
            string("英語"),
            string("物理"),
        ]
    }

    static func chartDateLabel(for period: Calendar.Component, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent

        switch period {
        case .day:
            formatter.setLocalizedDateFormatFromTemplate("Md")
            return formatter.string(from: date)
        case .weekOfYear:
            formatter.setLocalizedDateFormatFromTemplate("Md")
            return format("%@週", formatter.string(from: date))
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("yMMM")
            return formatter.string(from: date)
        case .year:
            formatter.setLocalizedDateFormatFromTemplate("y")
            return formatter.string(from: date)
        default:
            formatter.setLocalizedDateFormatFromTemplate("Md")
            return formatter.string(from: date)
        }
    }

    static func monthHeader(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }
}
