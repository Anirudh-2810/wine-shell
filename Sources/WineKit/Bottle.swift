import Foundation

/// An isolated Wine prefix + its settings. OS-agnostic: no Apple imports.
public struct Bottle: Codable, Equatable {
    public var name: String
    public var url: URL
    public var wineVersion: String
    public var backend: GraphicsBackend
    public var windowsVersion: String
    public var customEnv: [String: String]

    public init(name: String, url: URL, wineVersion: String,
                backend: GraphicsBackend = .wined3d,
                windowsVersion: String = "win10",
                customEnv: [String: String] = [:]) {
        self.name = name
        self.url = url
        self.wineVersion = wineVersion
        self.backend = backend
        self.windowsVersion = windowsVersion
        self.customEnv = customEnv
    }
}

/// One Windows executable inside a bottle.
public struct Program: Codable, Equatable {
    public var name: String
    public var exePath: String
    public var args: [String]
    public var env: [String: String]
    public var backendOverride: GraphicsBackend?

    public init(name: String, exePath: String, args: [String] = [],
                env: [String: String] = [:],
                backendOverride: GraphicsBackend? = nil) {
        self.name = name
        self.exePath = exePath
        self.args = args
        self.env = env
        self.backendOverride = backendOverride
    }
}
