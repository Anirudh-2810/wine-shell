import XCTest
@testable import WineKit

final class BackendDeployerTests: XCTestCase {
    private func makeTree() throws -> (payload: URL, prefix: URL) {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let payload = base.appendingPathComponent("payload")
        let prefix = base.appendingPathComponent("prefix/drive_c/windows", isDirectory: true)
        for d in [payload.appendingPathComponent("x64"), payload.appendingPathComponent("x32"),
                  prefix.appendingPathComponent("system32"), prefix.appendingPathComponent("syswow64")] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
        for dll in ["d3d11.dll", "d3d10core.dll", "dxgi.dll"] {
            for arch in ["x64", "x32"] {
                try Data("dll".utf8).write(to: payload.appendingPathComponent("\(arch)/\(dll)"))
            }
        }
        return (payload, base.appendingPathComponent("prefix"))
    }

    func testDeployDXVK() throws {
        let (payload, prefix) = try makeTree()
        try BackendDeployer().deploy(backend: .dxvk, payloadRoot: payload, prefixRoot: prefix)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: prefix.appendingPathComponent("drive_c/windows/system32/d3d11.dll").path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: prefix.appendingPathComponent("drive_c/windows/syswow64/dxgi.dll").path))
    }

    func testFailClosedOnMissingDLL() throws {
        let (payload, prefix) = try makeTree()
        // Remove one 32-bit DLL → whole deploy must fail BEFORE touching prefix.
        try FileManager.default.removeItem(at: payload.appendingPathComponent("x32/dxgi.dll"))
        XCTAssertThrowsError(
            try BackendDeployer().deploy(backend: .dxvk, payloadRoot: payload, prefixRoot: prefix))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: prefix.appendingPathComponent("drive_c/windows/system32/d3d11.dll").path))
    }

    func testWined3dDeploysNothing() throws {
        let (payload, prefix) = try makeTree()
        XCTAssertNoThrow(try BackendDeployer().deploy(backend: .wined3d, payloadRoot: payload, prefixRoot: prefix))
    }

    func testNextBackendCycle() {
        XCTAssertEqual(BackendDeployer.next(after: .dxvk), .dxmt)
        XCTAssertEqual(BackendDeployer.next(after: .dxmt), .wined3d)
        XCTAssertEqual(BackendDeployer.next(after: .wined3d), .dxvk)
        XCTAssertEqual(BackendDeployer.next(after: .d3dMetal), .d3dMetal) // never auto-cycled
    }
}

final class GPTKValidatorTests: XCTestCase {
    /// Builds a fake GPTK `lib` tree; `builtin` controls the winebuild marker.
    private func makePayload(builtin: Bool) throws -> URL {
        let lib = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("lib")
        let peDir = lib.appendingPathComponent("wine/x86_64-windows")
        let ext = lib.appendingPathComponent("external")
        try FileManager.default.createDirectory(at: peDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ext, withIntermediateDirectories: true)
        try Data("dylib".utf8).write(to: ext.appendingPathComponent("libd3dshared.dylib"))
        try FileManager.default.createDirectory(
            at: ext.appendingPathComponent("D3DMetal.framework"), withIntermediateDirectories: true)
        for name in GPTKValidator.forwarderDLLs {
            var bytes = Data(count: 0x50)
            if builtin {
                let sig = Data("Wine builtin DLL".utf8)
                bytes.replaceSubrange(0x40..<(0x40 + sig.count), with: sig)
            }
            try bytes.write(to: peDir.appendingPathComponent(name))
        }
        return lib
    }

    func testValidPayload() throws {
        let lib = try makePayload(builtin: true)
        XCTAssertNotNil(GPTKValidator.locatePayload(under: lib.deletingLastPathComponent()))
        XCTAssertNoThrow(try GPTKValidator().validate(libRoot: lib))
    }

    func testNativeDLLRejected() throws {
        let lib = try makePayload(builtin: false)
        XCTAssertThrowsError(try GPTKValidator().validate(libRoot: lib))
    }

    func testIncompleteRejected() throws {
        let lib = try makePayload(builtin: true)
        try FileManager.default.removeItem(
            at: lib.appendingPathComponent("external/libd3dshared.dylib"))
        XCTAssertThrowsError(try GPTKValidator().validate(libRoot: lib))
    }
}

final class BottleArchiveTests: XCTestCase {
    func testExportImportRoundTrip() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bottleDir = base.appendingPathComponent("mybottle", isDirectory: true)
        try FileManager.default.createDirectory(at: bottleDir, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            atPath: bottleDir.appendingPathComponent("link").path,
            withDestinationPath: "target")
        try Data("t".utf8).write(to: bottleDir.appendingPathComponent("target"))
        let archive = base.appendingPathComponent("mybottle.tar.gz")
        try BottleArchive().exportBottle(bottleDir: bottleDir, to: archive)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archive.path))
        let dest = base.appendingPathComponent("restored", isDirectory: true)
        try BottleArchive().import(archive: archive, to: dest)
        // Symlink must survive as a symlink (tar, never zip).
        let values = try dest.appendingPathComponent("mybottle/link").resourceValues(forKeys: [.isSymbolicLinkKey])
        XCTAssertEqual(values.isSymbolicLink, true)
    }
}
