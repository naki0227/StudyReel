import Foundation
import SwiftData
import SwiftUI

@Model
class StudySession {
    var id: UUID
    var date: Date
    var duration: Int
    var subject: String
    var recordedAt: Date?
    // 1.5 で追加。既存の記録は nil のまま
    var title: String?
    var memo: String?
    var thumbnailFileName: String?
    var videoFileName: String?
    
    @Relationship(inverse: \Tag.sessions)
    var tags: [Tag]? = []
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: Int,
        subject: String,
        tags: [Tag] = [],
        recordedAt: Date? = nil,
        title: String? = nil,
        memo: String? = nil,
        thumbnailFileName: String? = nil,
        videoFileName: String? = nil
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.subject = subject
        self.tags = tags
        self.recordedAt = recordedAt
        self.title = title
        self.memo = memo
        self.thumbnailFileName = thumbnailFileName
        self.videoFileName = videoFileName
    }

    // タイトルが空なら教科名を見出しにする
    var displayTitle: String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? subject : trimmed
    }
}

@Model
class Tag {
    var name: String
    var colorHex: String
    var sessions: [StudySession]? = []
    
    init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

@Model
class DailyGoal {
    var date: Date // The date this goal applies to (normalized to start of day)
    var targetDuration: Int // In seconds
    
    init(date: Date, targetDuration: Int) {
        self.date = date
        self.targetDuration = targetDuration
    }
}

// Helper for Color <-> Hex
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0

        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }

    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)

        if components.count >= 4 {
            a = Float(components[3])
        }

        if a != 1.0 {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}
