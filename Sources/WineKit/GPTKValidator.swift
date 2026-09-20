import Foundation

/// Validates a user-supplied Game Porting Toolkit payload (mounted DMG).
/// Apple-proprietary: NEVER downloaded or bundled — the user points at their
/// own DMG and this gates the D3DMetal picker option. Mirrors Whisky's
/// GPTKImporter validation (presence + builtin-marker checks).
public struct GPTKValidator {
    public var fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public enum ValidationError: Error, Equatable {
        case incomplete(missing: [String])
        case notGPTK(String)
    }

    /// PE forwarder DLLs Apple ships in `lib/wine/x86_64-windows/`.
    public static let forwarderDLLs = [
        "d3d10.dll", "d3d10core.dll", "d3d11.dll",
        "d3d12.dll", "dxgi.dll", "d3dcompiler_47.dll",
    ]

    /// Accepts the `lib` dir itself, a `redist` dir, or a mounted volume root.
    public static func locatePayload(under url: URL, fileManager: FileManager = .default) -> URL? {
        let candidates = [url,
                          url.appendingPathComponent("lib"),
                          url.appendingPathComponent("redist/lib")]
        return candidates.first(where: { isPayloadRoot($0, fileManager: fileManager) })
    }

    private static func isPayloadRoot(_ url: URL, fileManager: FileManager) -> Bool {
        fileManager.fileExists(atPath: url.appendingPathComponent("external/libd3dshared.dylib").path)
            && fileManager.fileExists(atPath: url.appendingPathComponent("wine/x86_64-windows/dxgi.dll").path)
    }

    /// Full validation: framework + shared lib + every forwarder present, and
    /// each forwarder must be the builtin variant (winebuild marker present).
    /// A native-marked file here means "not a GPTK payload" → reject.
    public func validate(libRoot: URL) throws {
        var missing: [String] = []
        let external = libRoot.appendingPathComponent("external")
        for name in ["libd3dshared.dylib", "D3DMetal.framework"] {
            if !fileManager.fileExists(atPath: external.appendingPathComponent(name).path) {
                missing.append("external/\(name)")
            }
        }
        let peDir = libRoot.appendingPathComponent("wine/x86_64-windows")
        for name in Self.forwarderDLLs {
            if !fileManager.fileExists(atPath: peDir.appendingPathComponent(name).path) {
                missing.append("wine/x86_64-windows/\(name)")
            }
        }
        guard missing.isEmpty else { throw ValidationError.incomplete(missing: missing) }
        for name in Self.forwarderDLLs {
            let dll = peDir.appendingPathComponent(name)
            guard isBuiltinPE(dll) else { throw ValidationError.notGPTK(name) }
        }
    }

    /// Apple's forwarders are winebuild builtins carrying the
    /// "Wine builtin DLL" marker at offset 0x40. Files too short to hold the
    /// marker fail closed (treated as NOT builtin).
    func isBuiltinPE(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let marker = try? handle.read(upToCount: 0x50), marker.count == 0x50 else { return false }
        let signature = Data("Wine builtin DLL".utf8)
        return marker[0x40..<(0x40 + signature.count)] == signature
    }
}
