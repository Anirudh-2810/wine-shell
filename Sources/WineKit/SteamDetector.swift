import Foundation

/// Steam library detection: finds installed Windows games via Steam's
/// `libraryfolders.vdf` + `appmanifest_*.acf` files. Works wherever Steam
/// lives (Mac: ~/Library/Application Support/Steam; Linux: ~/.steam/steam).
/// Pure file parsing — fully testable with fixtures.
public struct SteamGame: Equatable {
    public var appID: String
    public var name: String
    public var installDir: URL
}

public struct SteamDetector {
    public var fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Candidate Steam roots in priority order. `home` injected for tests.
    public static func roots(home: URL) -> [URL] {
        [
            home.appendingPathComponent("Library/Application Support/Steam"),
            home.appendingPathComponent(".steam/steam"),
            home.appendingPathComponent(".local/share/Steam"),
        ]
    }

    /// All detected games across every library folder. Empty when no Steam.
    public func games(home: URL) -> [SteamGame] {
        for root in Self.roots(home: home) {
            let steamapps = root.appendingPathComponent("steamapps")
            guard fileManager.fileExists(atPath: steamapps.path) else { continue }
            var libraries = [steamapps]
            let vdf = steamapps.appendingPathComponent("libraryfolders.vdf")
            if let text = try? String(contentsOf: vdf, encoding: .utf8) {
                libraries += parseLibraryFolders(text, relativeTo: root)
            }
            // libraryfolders.vdf usually re-lists its own dir — dedupe paths.
            var seen = Set<String>()
            libraries = libraries.filter { seen.insert($0.path).inserted }
            let found = libraries.flatMap { manifests(in: $0) }
            if !found.isEmpty { return found }
        }
        return []
    }

    /// Pulls quoted "path" values out of libraryfolders.vdf (VDF-lite: we only
    /// need paths, not the full tree — robust to Valve's format drift).
    func parseLibraryFolders(_ text: String, relativeTo root: URL) -> [URL] {
        var urls: [URL] = []
        for line in text.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: "\"").map { $0.trimmingCharacters(in: .whitespaces) }
            // lines look like: "path"  "/Volumes/Games/Steam"  — find "path" key
            if let i = parts.firstIndex(of: "path"), i + 2 < parts.count {
                let raw = parts[i + 2].replacingOccurrences(of: "\\\\", with: "/")
                let dir = URL(fileURLWithPath: raw).appendingPathComponent("steamapps")
                if fileManager.fileExists(atPath: dir.path) { urls.append(dir) }
            }
        }
        return urls
    }

    private func manifests(in steamapps: URL) -> [SteamGame] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: steamapps, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.lastPathComponent.hasPrefix("appmanifest_") }
            .compactMap { parseManifest($0, steamapps: steamapps) }
    }

    private func parseManifest(_ url: URL, steamapps: URL) -> SteamGame? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        func value(_ key: String) -> String? {
            for line in text.components(separatedBy: .newlines) {
                let parts = line.components(separatedBy: "\"")
                if let i = parts.firstIndex(of: key), i + 2 < parts.count {
                    return parts[i + 2]
                }
            }
            return nil
        }
        guard let appID = value("appid"), let name = value("name"),
              let dir = value("installdir") else { return nil }
        return SteamGame(appID: appID, name: name,
                         installDir: steamapps.appendingPathComponent("common/\(dir)"))
    }
}
