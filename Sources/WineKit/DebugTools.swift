import Foundation

/// One captured process run, kept for the debug console + bundles.
public struct RunRecord: Codable, Equatable {
    public var date: Date
    public var bottle: String
    public var program: String
    public var args: [String]
    public var exitCode: Int32
    public var logTail: String
}

/// In-memory run log (cap 200 records). Powers the debug console view.
public struct LogStore: Equatable {
    public private(set) var records: [RunRecord] = []
    public var capacity = 200

    public init() {}

    public mutating func append(_ record: RunRecord) {
        records.append(record)
        if records.count > capacity { records.removeFirst(records.count - capacity) }
    }

    public func filtered(bottle: String? = nil, failuresOnly: Bool = false) -> [RunRecord] {
        records.filter { r in
            (bottle == nil || r.bottle == bottle) && (!failuresOnly || r.exitCode != 0)
        }
    }
}

/// Debug bundle: one markdown report with everything needed to file an issue
/// (CrossOver "Run with Options" log-file equivalent, portable).
public struct DebugBundle {
    /// Renders `bottle` + `records` + `wineVersion` as markdown.
    public static func render(bottle: Bottle, records: [RunRecord],
                              wineVersion: String, os: String) -> String {
        var lines = [
            "# wine-shell debug bundle",
            "",
            "- Bottle: \(bottle.name) (backend: \(bottle.backend.rawValue), prefix wine: \(bottle.wineVersion))",
            "- Runtime wine: \(wineVersion)",
            "- OS: \(os)",
            "- Runs: \(records.count)",
            "",
        ]
        for r in records.suffix(10) {
            lines += [
                "## \(r.date) — \(r.program) (exit \(r.exitCode))",
                "args: \(r.args.joined(separator: " "))",
                "```",
                r.logTail,
                "```",
                "",
            ]
        }
        return lines.joined(separator: "\n")
    }
}

/// Update check against GitHub Releases (injectable fetch → offline-testable).
public struct UpdateCheck {
    public struct Release: Equatable {
        public var tag: String
    }

    /// Parses `tag_name` values out of a releases-API payload (order kept).
    public static func parseTags(_ json: Data) -> [String] {
        guard let arr = try? JSONSerialization.jsonObject(with: json) as? [[String: Any]] else {
            return []
        }
        return arr.compactMap { $0["tag_name"] as? String }
    }

    /// True when `latest` is newer than `current` (numeric compare, `v` tolerant).
    public static func isNewer(latest: String, than current: String) -> Bool {
        let norm: (String) -> String = { $0.hasPrefix("v") ? String($0.dropFirst()) : $0 }
        return norm(latest).compare(norm(current), options: .numeric) == .orderedDescending
    }
}
