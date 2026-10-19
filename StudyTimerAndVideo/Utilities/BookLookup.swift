import Foundation
import UIKit

// 本の裏のバーコード（ISBN）から書名と表紙を調べる。
// 送るのは ISBN だけ。openBD（無料・登録不要）で見つからなければ国立国会図書館サーチに聞く
struct BookInfo {
    var isbn: String
    var title: String
    var author: String?
    var cover: UIImage?
}

enum BookLookup {
    // 日本の本にはバーコードが2段あるので、978/979 で始まる方だけを ISBN として扱う
    static func normalizedISBN(_ code: String) -> String? {
        let digits = code.filter(\.isNumber)
        guard digits.count == 13, digits.hasPrefix("978") || digits.hasPrefix("979") else { return nil }
        let values = digits.compactMap { $0.wholeNumberValue }
        let sum = values.prefix(12).enumerated().reduce(0) { $0 + $1.element * ($1.offset % 2 == 0 ? 1 : 3) }
        guard (10 - sum % 10) % 10 == values[12] else { return nil }
        return digits
    }

    static func lookup(isbn: String) async -> BookInfo? {
        if let info = await openBD(isbn: isbn) {
            return info
        }
        return await ndl(isbn: isbn)
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        return URLSession(configuration: configuration)
    }()

    private static func openBD(isbn: String) async -> BookInfo? {
        guard let url = URL(string: "https://api.openbd.jp/v1/get?isbn=\(isbn)"),
              let (data, _) = try? await session.data(from: url),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let first = array.first as? [String: Any],
              let summary = first["summary"] as? [String: Any],
              let title = (summary["title"] as? String)?.trimmingCharacters(in: .whitespaces),
              !title.isEmpty else { return nil }

        let author = (summary["author"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        var cover: UIImage?
        if let coverString = summary["cover"] as? String, let coverURL = URL(string: coverString) {
            cover = await image(from: coverURL)
        }
        return BookInfo(isbn: isbn, title: title, author: author, cover: cover)
    }

    private static func ndl(isbn: String) async -> BookInfo? {
        guard let url = URL(string: "https://ndlsearch.ndl.go.jp/api/opensearch?isbn=\(isbn)&cnt=1"),
              let (data, _) = try? await session.data(from: url) else { return nil }
        let parser = FirstItemParser(data: data)
        guard let title = parser.title, !title.isEmpty else { return nil }
        var cover: UIImage?
        if let coverURL = URL(string: "https://ndlsearch.ndl.go.jp/thumbnail/\(isbn).jpg") {
            cover = await image(from: coverURL)
        }
        return BookInfo(isbn: isbn, title: title, author: parser.author, cover: cover)
    }

    private static func image(from url: URL) async -> UIImage? {
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return UIImage(data: data)
    }
}

// 国立国会図書館サーチの結果（RSS）から、最初の本の書名と著者だけを取り出す
private final class FirstItemParser: NSObject, XMLParserDelegate {
    private(set) var title: String?
    private(set) var author: String?
    private var inItem = false
    private var current = ""
    private var element = ""

    init(data: Data) {
        super.init()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "item" { inItem = true }
        element = elementName
        current = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        current += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard inItem else { return }
        let text = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if elementName == "title", title == nil {
            title = text
        } else if elementName == "author", author == nil {
            author = text
        } else if elementName == "item" {
            parser.abortParsing()
        }
        current = ""
    }
}
