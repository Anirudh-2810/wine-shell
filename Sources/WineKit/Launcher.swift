import Foundation

/// Result of a Wine child-process run.
public struct RunResult: Equatable {
    public var exitCode: Int32
    public var logTail: String
}

public enum LauncherError: Error, Equatable {
    case timeout
    case launchFailed(String)
}

/// Runs Wine programs. Injected `wineURL` (never hardcoded) keeps this testable on any OS.
public struct LocalWineLauncher {
    public var wineURL: URL
    public var fileManager: FileManager

    public init(wineURL: URL, fileManager: FileManager = .default) {
        self.wineURL = wineURL
        self.fileManager = fileManager
    }

    /// Runs `args` under `env`, draining output async (never blocking-read).
    /// Throws `LauncherError.timeout` after `timeout` seconds (child killed).
    public func run(args: [String], env: [String: String],
                    timeout: TimeInterval) async throws -> RunResult {
        let process = Process()
        process.executableURL = wineURL
        process.arguments = args
        var merged = ProcessInfo.processInfo.environment
        for (k, v) in env { merged[k] = v }
        process.environment = merged
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        var output = Data()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { output.append(chunk) }
        }
        do { try process.run() } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            throw LauncherError.launchFailed("\(error)")
        }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Date() > deadline {
                process.terminate()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if process.isRunning { process.interrupt() }
                pipe.fileHandleForReading.readabilityHandler = nil
                throw LauncherError.timeout
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        pipe.fileHandleForReading.readabilityHandler = nil
        let tail = String(data: output.suffix(2000), encoding: .utf8) ?? "<non-utf8>"
        return RunResult(exitCode: process.terminationStatus, logTail: tail)
    }
}
