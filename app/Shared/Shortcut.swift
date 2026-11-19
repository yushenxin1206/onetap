import Foundation

struct Shortcut: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var appID: String
    var actionID: String
}
