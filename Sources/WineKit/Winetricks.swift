import Foundation

/// winetricks wrapper + log-to-verb suggestion (the #1 real-world failure path).
public struct Winetricks {
    public var launcher: LocalWineLauncher
    public var winetricksURL: URL

    public init(launcher: LocalWineLauncher, winetricksURL: URL) {
        self.launcher = launcher
        self.winetricksURL = winetricksURL
    }

    /// Installs a verb (e.g. `vcrun2019`, `corefonts`) into the bottle.
    @discardableResult
    public func install(verb: String, bottle: Bottle) async throws -> RunResult {
        var launcher = launcher
        launcher.wineURL = winetricksURL
        let env = WineEnvironment.build(bottle: bottle)
        return try await launcher.run(args: [verb], env: env, timeout: 600)
    }

    /// Maps "missing DLL" log text to the exact winetricks verb. Top-5 set.
    public static func suggestVerb(forLog log: String) -> String? {
        let lower = log.lowercased()
        let table: [(verb: String, markers: [String])] = [
            ("vcrun2019", ["vcrun", "msvcp140", "msvcr", "vcomp140", "api-ms-win-crt"]),
            ("corefonts", ["font", "dwrite", "freetype"]),
            ("d3dx9", ["d3dx9_", "d3dx10_"]),
            ("dotnet48", ["mscorlib", ".net", "clr"]),
            ("xact", ["xaudio", "xactengine", "x3daudio"]),
        ]
        for (verb, markers) in table {
            for marker in markers where lower.contains(marker) { return verb }
        }
        return nil
    }
}
