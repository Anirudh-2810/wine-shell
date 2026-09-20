import Foundation

/// Bottle lifecycle flows over a launcher: init / update / reboot-sim / kill / repair.
public struct WineBoot {
    public var launcher: LocalWineLauncher

    public init(launcher: LocalWineLauncher) {
        self.launcher = launcher
    }

    private func boot(_ bottle: Bottle, _ command: String) async throws -> RunResult {
        let env = WineEnvironment.build(bottle: bottle)
        return try await launcher.run(args: [command], env: env, timeout: 90)
    }

    /// First-time prefix creation. Throws on hang (timeout) or failure.
    @discardableResult
    public func initialize(_ bottle: Bottle) async throws -> RunResult {
        try await boot(bottle, "wineboot --init")
    }

    /// Refresh prefix after runtime upgrade.
    @discardableResult
    public func update(_ bottle: Bottle) async throws -> RunResult {
        try await boot(bottle, "wineboot --update")
    }

    /// CrossOver "Simulate Reboot" for installers that demand it.
    @discardableResult
    public func simulateReboot(_ bottle: Bottle) async throws -> RunResult {
        try await boot(bottle, "wineboot --restart")
    }

    /// CrossOver "Quit All": kill every process in the bottle (unsaved work may be lost).
    @discardableResult
    public func quitAll(_ bottle: Bottle) async throws -> RunResult {
        let env = WineEnvironment.build(bottle: bottle)
        return try await launcher.run(args: ["wineserver", "-k"], env: env, timeout: 30)
    }

    /// Repair flow: kill stale server, drop lockfile, update prefix.
    public func repair(_ bottle: Bottle) async throws {
        _ = try? await quitAll(bottle)
        let lock = bottle.url.appendingPathComponent(".winelock")
        try? FileManager.default.removeItem(at: lock)
        _ = try await update(bottle)
    }
}
