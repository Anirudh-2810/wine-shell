import Foundation

/// Minimal PE/COFF reader: validates MZ + PE signature and reports machine
/// type. Feeds the refusal engine (ARM64-only or 16-bit binaries can't run
/// under Wine-on-Mac) and the future icon extractor (resource dir presence).
public struct PEInfo: Equatable {
    public enum Machine: UInt16, Equatable {
        case i386 = 0x014C
        case amd64 = 0x8664
        case arm64 = 0xAA64
        case arm = 0x01C0
        case unknown = 0x0000
    }
    public var machine: Machine
    public var hasResources: Bool
}

public struct PEParser {
    public enum PEError: Error, Equatable {
        case tooSmall
        case badMZ
        case badPEOffset
        case badPESignature
    }

    /// Parses raw exe bytes. Throws on non-PE files (fail-closed: callers
    /// treat parse failure as "unknown, proceed with caution").
    public static func parse(_ data: Data) throws -> PEInfo {
        guard data.count >= 64 else { throw PEError.tooSmall }
        guard data[0] == 0x4D, data[1] == 0x5A else { throw PEError.badMZ } // "MZ"
        let peOffset = Int(readU32(data, at: 0x3C))
        guard peOffset > 0, peOffset + 6 <= data.count else { throw PEError.badPEOffset }
        guard data[peOffset] == 0x50, data[peOffset + 1] == 0x45,
              data[peOffset + 2] == 0x00, data[peOffset + 3] == 0x00 else {
            throw PEError.badPESignature // "PE\0\0"
        }
        let machineRaw = readU16(data, at: peOffset + 4)
        let machine = PEInfo.Machine(rawValue: machineRaw) ?? .unknown
        // Optional header size tells where section table starts; resource dir
        // presence = icons/version info extractable later.
        let numSections = Int(readU16(data, at: peOffset + 6))
        let optSize = Int(readU16(data, at: peOffset + 20))
        var hasResources = false
        var off = peOffset + 24 + optSize
        for _ in 0..<min(numSections, 32) {
            guard off + 8 <= data.count else { break }
            if data[off..<off + 8].elementsEqual(".rsrc\u{0}\u{0}\u{0}".utf8) {
                hasResources = true
                break
            }
            off += 40
        }
        return PEInfo(machine: machine, hasResources: hasResources)
    }

    private static func readU16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readU32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
    }
}

extension RefusalCheck {
    /// PE-aware refusal: 16-bit/ARM64-only binaries can't run under Wine-on-Mac.
    /// Returns nil (no refusal) when the binary looks runnable or is unreadable.
    public static func checkPE(_ data: Data) -> Refusal? {
        guard let info = try? PEParser.parse(data) else { return nil }
        switch info.machine {
        case .arm64:
            return Refusal(
                reason: "ARM64-only Windows binary — Wine-on-Mac runs x86_64 code via Rosetta, not ARM64EC.",
                suggestion: "Look for an x64 build of this app, or run Windows 11 ARM in UTM/VMware.")
        case .unknown:
            return Refusal(
                reason: "Unrecognized machine type — likely 16-bit or newer-than-Wine format.",
                suggestion: "16-bit apps need DOSBox/UTM; otherwise try anyway and file the log.")
        case .i386, .amd64, .arm:
            return nil
        }
    }
}
