import Foundation

/// Deploys a graphics backend's DLLs from a runtime payload into a bottle's
/// prefix — the per-bottle, prefix-local model (Whisky `enableDXVK` pattern).
/// All paths injected: fully testable with temp dirs, no Wine needed.
public struct BackendDeployer {
    public var fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public enum DeployError: Error, Equatable {
        case payloadMissing(String)
        case prefixMissing(String)
    }

    /// DLL sets each backend needs inside system32/syswow64.
    public static func dlls(for backend: GraphicsBackend) -> [String] {
        switch backend {
        case .wined3d: return []
        case .dxvk: return ["d3d11.dll", "d3d10core.dll", "dxgi.dll"]
        case .dxmt: return ["d3d11.dll", "d3d10core.dll", "dxgi.dll", "winemetal.dll"]
        case .d3dMetal: return [] // deployed from the GPTK payload, see GPTKValidator
        }
    }

    /// Copies `dlls` from `payloadRoot/<arch>/` into the prefix's
    /// `drive_c/windows/{system32,syswow64}`. x64 always; x32 only when
    /// syswow64 exists. Fail-closed: validates EVERY source before touching
    /// the prefix — never half-deploys.
    public func deploy(backend: GraphicsBackend,
                       payloadRoot: URL, prefixRoot: URL) throws {
        let needed = Self.dlls(for: backend)
        guard !needed.isEmpty else { return } // wined3d: nothing to deploy
        let windows = prefixRoot.appendingPathComponent("drive_c/windows", isDirectory: true)
        let system32 = windows.appendingPathComponent("system32", isDirectory: true)
        guard fileManager.fileExists(atPath: system32.path) else {
            throw DeployError.prefixMissing(system32.path)
        }
        let syswow64 = windows.appendingPathComponent("syswow64", isDirectory: true)
        let deploy32 = fileManager.fileExists(atPath: syswow64.path)

        // Validate all sources FIRST.
        var copies: [(from: URL, to: URL)] = []
        for name in needed {
            let src64 = payloadRoot.appendingPathComponent("x64/\(name)")
            guard fileManager.fileExists(atPath: src64.path) else {
                throw DeployError.payloadMissing(src64.path)
            }
            copies.append((src64, system32.appendingPathComponent(name)))
            if deploy32 {
                let src32 = payloadRoot.appendingPathComponent("x32/\(name)")
                guard fileManager.fileExists(atPath: src32.path) else {
                    throw DeployError.payloadMissing(src32.path)
                }
                copies.append((src32, syswow64.appendingPathComponent(name)))
            }
        }
        // All valid — now copy.
        for (from, to) in copies {
            if fileManager.fileExists(atPath: to.path) {
                try fileManager.removeItem(at: to)
            }
            try fileManager.copyItem(at: from, to: to)
        }
    }

    /// Backend fallback cycle for "try next backend": DXVK → DXMT → wined3d.
    /// D3DMetal is never auto-cycled (needs a user-supplied GPTK payload).
    public static func next(after backend: GraphicsBackend) -> GraphicsBackend {
        switch backend {
        case .dxvk: return .dxmt
        case .dxmt: return .wined3d
        case .wined3d: return .dxvk
        case .d3dMetal: return .d3dMetal
        }
    }
}
