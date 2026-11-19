import Foundation

/// 实测结果只属于这台机器，和动作定义分开存放。
enum RunResult: String, Codable, Hashable {
    case reachable
    case unreachable

    var label: String {
        switch self {
        case .reachable: return "可用"
        case .unreachable: return "打不开"
        }
    }
}

enum RunVia: String, Codable, Hashable {
    case web
    case scheme
    case shortcut

    var label: String {
        switch self {
        case .web: return "网页链接"
        case .scheme: return "App 链接"
        case .shortcut: return "快捷指令"
        }
    }
}

struct RunRecord: Codable, Hashable {
    var appID: String
    var actionID: String
    var result: RunResult
    var lastRunAt: Date?
    var via: RunVia?
}

struct RunLogData: Codable {
    var records: [RunRecord]
}

@MainActor
final class RunLogStore: ObservableObject {
    static let shared = RunLogStore()

    private static let storageKey = "onetap.runlog.v1"

    @Published private(set) var records: [RunRecord] = []

    init() {
        if
            let data = OneTapShared.defaults.data(forKey: Self.storageKey),
            let decoded = try? JSONDecoder().decode(RunLogData.self, from: data)
        {
            records = decoded.records
        }
    }

    func record(appID: String, actionID: String) -> RunRecord? {
        records.first { $0.appID == appID && $0.actionID == actionID }
    }

    func mark(appID: String, actionID: String, result: RunResult, via: RunVia?) {
        let record = RunRecord(
            appID: appID,
            actionID: actionID,
            result: result,
            lastRunAt: Date(),
            via: via
        )
        if let index = records.firstIndex(where: { $0.appID == appID && $0.actionID == actionID }) {
            records[index] = record
        } else {
            records.append(record)
        }
        persist()
    }

    func clear(appID: String, actionID: String) {
        let before = records.count
        records.removeAll { $0.appID == appID && $0.actionID == actionID }
        if records.count != before { persist() }
    }

    func clear(appID: String) {
        let before = records.count
        records.removeAll { $0.appID == appID }
        if records.count != before { persist() }
    }

    func prune(validKeys: Set<String>) {
        let before = records.count
        records.removeAll { !validKeys.contains("\($0.appID)/\($0.actionID)") }
        if records.count != before { persist() }
    }

    func restore(_ restored: [RunRecord]) {
        for record in restored where self.record(appID: record.appID, actionID: record.actionID) == nil {
            records.append(record)
        }
        persist()
    }

    /// 旧版动作上的实测结果只搬一次，时间未知。
    func importLegacy(appID: String, actionID: String, result: RunResult) {
        guard record(appID: appID, actionID: actionID) == nil else { return }
        records.append(
            RunRecord(
                appID: appID,
                actionID: actionID,
                result: result,
                lastRunAt: nil,
                via: nil
            )
        )
        persist()
    }

    private func persist() {
        let payload = RunLogData(records: records)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        OneTapShared.defaults.set(data, forKey: Self.storageKey)
    }
}
