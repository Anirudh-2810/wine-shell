import XCTest
@testable import WineKit

final class BottleStoreTests: XCTestCase {
    private func freshStore() throws -> BottleStore {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return BottleStore(root: dir)
    }

    func testCreateOpenListDelete() throws {
        let store = try freshStore()
        _ = try store.create(name: "app", wineVersion: "9.0")
        XCTAssertEqual(try store.list(), ["app"])
        let opened = try store.open(name: "app", currentWineVersion: "9.0")
        XCTAssertEqual(opened.backend, .wined3d)
        try store.delete(name: "app")
        XCTAssertEqual(try store.list(), [])
    }

    func testDuplicateCreatesIndependentCopy() throws {
        let store = try freshStore()
        _ = try store.create(name: "a", wineVersion: "9.0")
        try store.duplicate(name: "a", as: "b")
        XCTAssertEqual(try store.list(), ["a", "b"])
        let b = try store.open(name: "b", currentWineVersion: "9.0")
        XCTAssertEqual(b.name, "b")
    }

    func testDowngradeGuard() throws {
        let store = try freshStore()
        _ = try store.create(name: "new", wineVersion: "10.0")
        XCTAssertThrowsError(try store.open(name: "new", currentWineVersion: "9.0"))
        // upgrade path is fine
        XCTAssertNoThrow(try store.open(name: "new", currentWineVersion: "10.0"))
    }

    func testMissingAndCorrupt() throws {
        let store = try freshStore()
        XCTAssertThrowsError(try store.open(name: "ghost", currentWineVersion: "9.0"))
        let dir = store.root.appendingPathComponent("bad", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("junk".utf8).write(to: dir.appendingPathComponent("bottle.plist"))
        XCTAssertThrowsError(try store.open(name: "bad", currentWineVersion: "9.0"))
    }
}

final class WinetricksTests: XCTestCase {
    func testSuggestions() {
        XCTAssertEqual(Winetricks.suggestVerb(forLog: "err:module:import_dll Library MSVCP140.dll not found"), "vcrun2019")
        XCTAssertEqual(Winetricks.suggestVerb(forLog: "dwrite: font fallback failed"), "corefonts")
        XCTAssertEqual(Winetricks.suggestVerb(forLog: "d3dx9_43 missing"), "d3dx9")
        XCTAssertNil(Winetricks.suggestVerb(forLog: "all good, rendering fine"))
    }
}

final class RuntimeInstallerTests: XCTestCase {
    func testVerifyKnownDigest() throws {
        // sha256("abc") — canonical test vector, no Wine needed.
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("abc".utf8).write(to: file)
        let installer = RuntimeInstaller()
        let digest = try installer.verify(file: file,
            expected: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(digest, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertThrowsError(try installer.verify(file: file, expected: String(repeating: "0", count: 64)))
    }

    func testIsInstalledGate() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bin = dir.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let installer = RuntimeInstaller()
        XCTAssertFalse(installer.isInstalled(at: dir))
        try Data("x".utf8).write(to: dir.appendingPathComponent("WineVersion.plist"))
        XCTAssertFalse(installer.isInstalled(at: dir)) // binary still missing
        let wine = bin.appendingPathComponent("wine")
        try Data("x".utf8).write(to: wine)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wine.path)
        XCTAssertTrue(installer.isInstalled(at: dir))
    }
}

/// Real-Wine integration: proves OUR launcher drives Wine. Runs only when
/// WINE_EXE is set (CI linux job); skipped everywhere else, including macOS.
final class LauncherIntegrationTests: XCTestCase {
    func testWinebootInitThroughLauncher() async throws {
        guard let exe = ProcessInfo.processInfo.environment["WINE_EXE"] else {
            throw XCTSkip("WINE_EXE unset — real-Wine proof runs in CI only")
        }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let bottle = Bottle(name: "ci", url: tmp, wineVersion: "ci")
        let launcher = LocalWineLauncher(wineURL: URL(fileURLWithPath: exe))
        let boot = WineBoot(launcher: launcher)
        let result = try await boot.initialize(bottle)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("drive_c").path))
    }
}
