import Foundation

// 最初から選べる定番の教材。版や年度は人によって違うので、名前は版を付けずに持つ
struct CatalogMaterial: Identifiable, Hashable {
    let name: String
    let subject: String
    let group: String

    var id: String { "\(group)/\(name)" }
}

enum MaterialCatalog {
    static let groups = ["教科書・学校", "大学受験", "英語の試験", "資格"]

    static let items: [CatalogMaterial] = {
        func list(_ group: String, _ subject: String, _ names: [String]) -> [CatalogMaterial] {
            names.map { CatalogMaterial(name: $0, subject: subject, group: group) }
        }
        return
            list("教科書・学校", "数学", ["数学の教科書", "数学の問題集（学校）"]) +
            list("教科書・学校", "英語", ["英語の教科書", "英単語帳（学校）"]) +
            list("教科書・学校", "国語", ["国語の教科書", "漢字問題集"]) +
            list("教科書・学校", "物理", ["物理の教科書"]) +
            list("教科書・学校", "化学", ["化学の教科書"]) +
            list("教科書・学校", "生物", ["生物の教科書"]) +
            list("教科書・学校", "日本史", ["日本史の教科書"]) +
            list("教科書・学校", "世界史", ["世界史の教科書"]) +
            list("教科書・学校", "その他", ["プリント・ノート", "過去のテスト"]) +

            list("大学受験", "数学", [
                "青チャート 数学I+A", "青チャート 数学II+B", "青チャート 数学III",
                "黄チャート 数学I+A", "黄チャート 数学II+B",
                "Focus Gold", "基礎問題精講 数学", "標準問題精講 数学",
                "1対1対応の演習", "やさしい理系数学", "大学への数学"
            ]) +
            list("大学受験", "英語", [
                "ターゲット1900", "ターゲット1400", "システム英単語", "速読英単語",
                "鉄緑会東大英単語熟語 鉄壁", "Next Stage", "Vintage", "Scramble 英文法・語法",
                "英文解釈の技術100", "ポレポレ英文読解プロセス50", "やっておきたい英語長文"
            ]) +
            list("大学受験", "国語", [
                "古文単語315", "マドンナ古文", "漢文早覚え速答法", "現代文キーワード読解"
            ]) +
            list("大学受験", "物理", ["物理のエッセンス", "良問の風", "名問の森", "物理重要問題集"]) +
            list("大学受験", "化学", ["化学の新研究", "セミナー化学", "化学重要問題集", "鎌田の理論化学"]) +
            list("大学受験", "生物", ["セミナー生物", "生物重要問題集"]) +
            list("大学受験", "日本史", ["日本史B 一問一答", "金谷の日本史"]) +
            list("大学受験", "世界史", ["世界史B 一問一答", "ナビゲーター世界史"]) +
            list("大学受験", "その他", ["共通テスト過去問", "赤本（志望校の過去問）"]) +

            list("英語の試験", "英語", [
                "TOEIC 金のフレーズ", "TOEIC 公式問題集", "英検 でる順パス単", "英検 過去問"
            ]) +

            list("資格", "資格", [
                "日商簿記3級", "日商簿記2級", "FP3級", "ITパスポート",
                "基本情報技術者", "宅建", "TOEFL", "漢検"
            ])
    }()

    static func search(_ text: String) -> [CatalogMaterial] {
        let query = text.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.subject.localizedCaseInsensitiveContains(query)
        }
    }
}
