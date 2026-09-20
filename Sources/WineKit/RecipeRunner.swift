import Foundation

/// Runs a minimal recipe: optional winetricks verbs → installer exe →
/// optional reboot-sim → verify installed exe exists. (CrossTie-inspired,
/// deliberately small — no crowd DB, ever.)
public struct RecipeRunner {
    public var launcher: LocalWineLauncher
    public var winetricksURL: URL?
    public var fileManager: FileManager

    public init(launcher: LocalWineLauncher, winetricksURL: URL? = nil,
                fileManager: FileManager = .default) {
        self.launcher = launcher
        self.winetricksURL = winetricksURL
        self.fileManager = fileManager
    }

    public enum RecipeError: Error, Equatable {
        case installerFailed(Int32, String)
        case exeMissing(String)
        case winetricksUnavailable
    }

    /// Runs the recipe against `bottle`. `installerExe` is a host path to the
    /// setup exe (outside the prefix); `recipe.exePath` is the C: path of the
    /// installed program, resolved under the prefix.
    @discardableResult
    public func run(recipe: Recipe, installerExe: URL, bottle: Bottle) async throws -> RunResult {
        if !recipe.winetricksVerbs.isEmpty {
            guard let wtURL = winetricksURL else { throw RecipeError.winetricksUnavailable }
            let wt = Winetricks(launcher: launcher, winetricksURL: wtURL)
            for verb in recipe.winetricksVerbs {
                _ = try await wt.install(verb: verb, bottle: bottle)
            }
        }
        let env = WineEnvironment.build(bottle: bottle)
        let install = try await launcher.run(
            args: [installerExe.path] + recipe.installerArgs, env: env, timeout: 600)
        guard install.exitCode == 0 else {
            throw RecipeError.installerFailed(install.exitCode, install.logTail)
        }
        if recipe.needsReboot {
            _ = try await WineBoot(launcher: launcher).simulateReboot(bottle)
        }
        let installed = bottle.url
            .appendingPathComponent("drive_c")
            .appendingPathComponent(recipe.exePath)
        guard fileManager.fileExists(atPath: installed.path) else {
            throw RecipeError.exeMissing(installed.path)
        }
        return install
    }
}

/// Bottle export/import via tar.gz (symlink-safe — never zip).
public struct BottleArchive {
    public var fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public enum ArchiveError: Error, Equatable {
        case toolMissing
        case failed(Int32)
    }

    private func tar(_ args: String...) throws {
        guard fileManager.isExecutableFile(atPath: "/bin/tar") else {
            throw ArchiveError.toolMissing
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/tar")
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ArchiveError.failed(process.terminationStatus)
        }
    }

    public func exportBottle(bottleDir: URL, to archive: URL) throws {
        try tar("-czf", archive.path, "-C", bottleDir.deletingLastPathComponent().path,
                bottleDir.lastPathComponent)
    }

    public func `import`(archive: URL, to destinationDir: URL) throws {
        try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        try tar("-xzf", archive.path, "-C", destinationDir.path)
    }
}
