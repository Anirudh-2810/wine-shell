import XCTest

#if canImport(SwiftUI)
@testable import WineShellUI
import WineKit

/// View-model tests: inject a temp store, exercise AppState without Wine.
/// Compile everywhere (guarded), execute meaningfully on macOS CI.
@MainActor
final class AppStateTests: XCTestCase {
    private func freshState() throws -> (AppState, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let state = AppState(storeRoot: dir)
        state.wineVersion = "9.0"
        return (state, dir)
    }

    func testInitialIdle() throws {
        let (state, _) = try freshState()
        XCTAssertEqual(state.status, "idle")
        XCTAssertTrue(state.bottles.isEmpty)
    }

    func testCreateReflectsInList() throws {
        let (state, _) = try freshState()
        state.createBottle(name: "game")
        XCTAssertEqual(state.bottles, ["game"])
    }

    func testDuplicateKeepsSingleEntryAndStatus() throws {
        let (state, _) = try freshState()
        state.createBottle(name: "game")
        state.createBottle(name: "game")
        XCTAssertEqual(state.bottles, ["game"])
        XCTAssertTrue(state.status.contains("failed"))
    }

    func testRunWithoutRuntimeWarns() async throws {
        let (state, _) = try freshState()
        state.createBottle(name: "game")
        let bottle = try state.store.open(name: "game", currentWineVersion: "9.0")
        await state.run(program: Program(name: "n", exePath: "C:\\n.exe"),
                        bottle: bottle, wineDEBUG: "")
        XCTAssertTrue(state.status.contains("Wine runtime"))
        XCTAssertTrue(state.log.records.isEmpty) // nothing launched, nothing logged
    }

    func testPickerDefaultIsBottleBackend() throws {
        let (state, _) = try freshState()
        state.createBottle(name: "game")
        var bottle = try state.store.open(name: "game", currentWineVersion: "9.0")
        bottle.backend = .dxvk
        let env = WineEnvironment.build(
            bottle: bottle, program: Program(name: "n", exePath: "C:\\n.exe"))
        XCTAssertTrue(env["WINEDLLOVERRIDES"]?.contains("d3d11=n,b") ?? false)
    }

    func testD3DMetalWarningCondition() throws {
        // The view warns exactly when the effective backend is .d3dMetal.
        let bottle = Bottle(name: "b", url: URL(fileURLWithPath: "/tmp/b"),
                            wineVersion: "9.0", backend: .d3dMetal)
        let program = Program(name: "n", exePath: "C:\\n.exe")
        XCTAssertEqual(program.backendOverride ?? bottle.backend, .d3dMetal)
    }

    func testLogFilterWired() throws {
        let (state, _) = try freshState()
        state.log.append(RunRecord(date: Date(), bottle: "game", program: "a.exe",
                                   args: [], exitCode: 0, logTail: "ok"))
        state.log.append(RunRecord(date: Date(), bottle: "game", program: "b.exe",
                                   args: [], exitCode: 1, logTail: "boom"))
        XCTAssertEqual(state.log.filtered(bottle: "game").count, 2)
        XCTAssertEqual(state.log.filtered(bottle: "game", failuresOnly: true).count, 1)
    }

    func testBundleSmoke() throws {
        let (state, _) = try freshState()
        state.createBottle(name: "game")
        let bottle = try state.store.open(name: "game", currentWineVersion: "9.0")
        let md = DebugBundle.render(bottle: bottle, records: state.log.records,
                                    wineVersion: "9.0", os: "TestOS")
        XCTAssertTrue(md.contains("game") && md.contains("Backend") || md.contains("backend"))
    }

    func testRefreshAfterExternalDelete() throws {
        let (state, dir) = try freshState()
        state.createBottle(name: "game")
        try FileManager.default.removeItem(at: dir.appendingPathComponent("game"))
        state.refresh()
        XCTAssertTrue(state.bottles.isEmpty)
    }
}
#else
// No SwiftUI here: nothing to drive.
#endif
