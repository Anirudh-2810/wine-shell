import Foundation

/// Pinned runtime manifest. Versions are exact — never "latest" (Whisky lesson).
public struct RuntimeManifest: Codable, Equatable {
    public var wineVersion: String
    public var wineURL: URL
    public var sha256: String
    public var fallbackURL: URL?

    public init(wineVersion: String, wineURL: URL, sha256: String, fallbackURL: URL? = nil) {
        self.wineVersion = wineVersion
        self.wineURL = wineURL
        self.sha256 = sha256
        self.fallbackURL = fallbackURL
    }
}

public enum RuntimeInstallError: Error, Equatable {
    case hashMismatch(expected: String, actual: String)
    case toolMissing(String)
    case downloadFailed(String)
}

/// Downloads + hash-gates + extracts a Wine runtime. Shells out to system
/// `sha256sum`/`shasum`/`tar` so WineKit stays dependency-free.
public struct RuntimeInstaller {
    public var fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Verifies `file` against `expected` hex digest. Returns actual digest.
    @discardableResult
    public func verify(file: URL, expected: String) throws -> String {
        let candidates = [
            ("/usr/bin/sha256sum", [file.path]),
            ("/bin/sha256sum", [file.path]),
            ("/usr/bin/shasum", ["-a", "256", file.path]),
        ]
        for (tool, args) in candidates where fileManager.isExecutableFile(atPath: tool) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = args
            let pipe = Pipe()
            process.standardOutput = pipe
            try process.run()
            process.waitUntilExit()
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let actual = out.split(separator: " ").first.map(String.init)?.lowercased() ?? ""
            guard !actual.isEmpty else { continue }
            guard actual == expected.lowercased() else {
                throw RuntimeInstallError.hashMismatch(expected: expected, actual: actual)
            }
            return actual
        }
        throw RuntimeInstallError.toolMissing("sha256sum/shasum")
    }

    /// Extracts a `.tar.gz`/`.tar.xz` runtime into `destination` (symlinks preserved).
    public func extract(archive: URL, to destination: URL) throws {
        let env = "/usr/bin/env" // tar lives in /bin on Linux, /usr/bin on macOS
        guard fileManager.isExecutableFile(atPath: env) else {
            throw RuntimeInstallError.toolMissing("tar")
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: env)
        process.arguments = ["tar", "-xf", archive.path, "-C", destination.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw RuntimeInstallError.downloadFailed("tar exit \(process.terminationStatus)")
        }
    }

    /// Runtime counts as installed only when version plist AND wine binary both exist.
    public func isInstalled(at runtimeDir: URL, wineBinaryName: String = "wine") -> Bool {
        let fm = fileManager
        return fm.fileExists(atPath: runtimeDir.appendingPathComponent("WineVersion.plist").path)
            && fm.isExecutableFile(atPath: runtimeDir.appendingPathComponent("bin/\(wineBinaryName)").path)
    }
}
