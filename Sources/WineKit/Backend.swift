import Foundation

/// Graphics translation backend selected per bottle (program may override).
public enum GraphicsBackend: String, Codable, CaseIterable {
    case wined3d
    case dxvk
    case dxmt
    case d3dMetal

    /// DLLs this backend deploys into system32/syswow64 + their overrides.
    /// `nil` = nothing to deploy (built-in path).
    public var dllOverrides: [String: String]? {
        switch self {
        case .wined3d: return nil
        case .dxvk: return ["d3d11": "n,b", "d3d10core": "n,b", "dxgi": "n,b"]
        case .dxmt: return ["d3d11": "n,b", "d3d10core": "n,b", "dxgi": "n,b", "winemetal": "b"]
        case .d3dMetal: return ["d3d11": "b", "d3d10core": "b", "dxgi": "b"]
        }
    }

    /// Extra environment required by this backend.
    public var extraEnv: [String: String] {
        switch self {
        case .wined3d: return [:]
        case .dxvk: return ["DXVK_ASYNC": "1", "MVK_CONFIG_RESUME_LOST_DEVICE": "1"]
        case .dxmt: return ["MTL_HUD_ENABLED": "0"]
        case .d3dMetal: return ["MTL_HUD_ENABLED": "0"]
        }
    }
}

/// Builds the launch environment in layers (simplified from Whisky's 8-layer model).
/// Precedence, lowest first: base → backend → bottle custom → program.
public struct WineEnvironment {
    public static func build(bottle: Bottle, program: Program? = nil) -> [String: String] {
        var env: [String: String] = [
            "WINEPREFIX": bottle.url.path,
            "WINEDEBUG": "fixme-all",
            "WINEESYNC": "1",
        ]
        let backend = program?.backendOverride ?? bottle.backend
        for (k, v) in backend.extraEnv { env[k] = v }
        if let dlls = backend.dllOverrides {
            env["WINEDLLOVERRIDES"] = dlls.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ";")
        }
        for (k, v) in bottle.customEnv { env[k] = v }
        if let program {
            for (k, v) in program.env { env[k] = v }
        }
        return env
    }
}
