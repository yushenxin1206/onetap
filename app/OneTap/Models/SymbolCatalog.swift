import Foundation
import UIKit

struct SymbolItem: Identifiable, Decodable {
    let name: String
    let label: String
    var id: String { name }
}

struct SymbolGroup: Identifiable, Decodable {
    let name: String
    let symbols: [SymbolItem]
    var id: String { name }
}

/// 内置精选图标清单。iOS 没有公开 API 枚举 SF Symbols，
/// 这里维护一份常用子集，并用 UIImage 过滤掉当前系统不存在的符号。
struct SymbolCatalog {
    static let shared = SymbolCatalog()

    let groups: [SymbolGroup]

    private init() {
        let url = Bundle.main.url(forResource: "symbol-catalog", withExtension: "json")
        let data = url.flatMap { try? Data(contentsOf: $0) }
        let decoded = data.flatMap { try? JSONDecoder().decode(CatalogFile.self, from: $0) }
        groups = (decoded?.groups ?? []).map { group in
            SymbolGroup(
                name: group.name,
                symbols: group.symbols.filter { Self.isValid($0.name) }
            )
        }
    }

    private struct CatalogFile: Decodable {
        let groups: [SymbolGroup]
    }

    var all: [SymbolItem] {
        groups.flatMap(\.symbols)
    }

    func search(_ query: String) -> [SymbolItem] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(keyword)
                || $0.label.localizedCaseInsensitiveContains(keyword)
        }
    }

    /// 运行时校验：系统里是否存在这个符号。
    static func isValid(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return UIImage(systemName: trimmed) != nil
    }

    /// 精选清单里是否有同名项，用于区分「拼错」和「冷门但合法」。
    func contains(_ name: String) -> Bool {
        all.contains { $0.name == name }
    }
}
