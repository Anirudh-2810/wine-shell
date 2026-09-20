import Foundation

/// Minimal install recipe (CrossTie-inspired, deliberately small).
public struct Recipe: Codable, Equatable {
    public var name: String
    public var downloadURL: URL?
    public var installerArgs: [String]
    public var exePath: String
    public var notes: String
    public var needsReboot: Bool
    public var winetricksVerbs: [String]

    public init(name: String, downloadURL: URL? = nil, installerArgs: [String] = [],
                exePath: String, notes: String = "", needsReboot: Bool = false,
                winetricksVerbs: [String] = []) {
        self.name = name
        self.downloadURL = downloadURL
        self.installerArgs = installerArgs
        self.exePath = exePath
        self.notes = notes
        self.needsReboot = needsReboot
        self.winetricksVerbs = winetricksVerbs
    }
}

/// Graceful refusal: detect what Wine can never run BEFORE wasting the user's time.
public struct Refusal: Equatable {
    public var reason: String
    public var suggestion: String
}

public struct RefusalCheck {
    /// Known-bad markers: kernel anti-cheat / driver installers / ARM-only binaries.
    public static let blockedNameFragments = [
        "easyanticheat", "faceit", "vgc", " Vanguard".lowercased(), "battleye",
        ".sys", "driver",
    ]

    /// Returns a refusal when `exeName` is known-unrunnable, else nil.
    public static func check(exeName: String) -> Refusal? {
        let lower = exeName.lowercased()
        for frag in blockedNameFragments where lower.contains(frag) {
            return Refusal(
                reason: "'\(exeName)' needs a real Windows kernel (anti-cheat/driver). Wine cannot load kernel drivers.",
                suggestion: "Use a VM (UTM/VMware) or real PC instead — see plan §4 S5."
            )
        }
        return nil
    }
}
