import XCTest
@testable import WineKit

final class PEParserTests: XCTestCase {
    /// Builds a minimal fake PE: MZ + e_lfanew + PE sig + COFF(machine, sections, optSize).
    private func fakePE(machine: UInt16, sections: [String] = []) -> Data {
        var d = Data(count: 256)
        d[0] = 0x4D; d[1] = 0x5A // MZ
        d[0x3C] = 0x40 // e_lfanew = 0x40
        d[0x40] = 0x50; d[0x41] = 0x45 // PE\0\0
        d[0x44] = UInt8(machine & 0xFF); d[0x45] = UInt8(machine >> 8)
        d[0x46] = UInt8(sections.count)
        d[0x54] = 0 // SizeOfOptionalHeader = 0 → sections start at 0x40+24
        var off = 0x40 + 24
        for name in sections {
            let bytes = Array(name.utf8.prefix(8))
            for (i, b) in bytes.enumerated() { d[off + i] = b }
            off += 40
        }
        return d
    }

    func testAMD64() throws {
        let info = try PEParser.parse(fakePE(machine: 0x8664, sections: [".rsrc"]))
        XCTAssertEqual(info.machine, .amd64)
        XCTAssertTrue(info.hasResources)
    }

    func testARM64Refused() throws {
        let data = fakePE(machine: 0xAA64)
        XCTAssertNotNil(RefusalCheck.checkPE(data))
    }

    func testRunnableNotRefused() throws {
        XCTAssertNil(RefusalCheck.checkPE(fakePE(machine: 0x8664)))
    }

    func testGarbageFailsClosed() {
        XCTAssertThrowsError(try PEParser.parse(Data("hello".utf8)))
        XCTAssertNil(RefusalCheck.checkPE(Data("hello".utf8))) // unknown → caution, not refusal
    }
}

final class SteamDetectorTests: XCTestCase {
    private func makeSteam() throws -> URL {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let apps = home.appendingPathComponent(".steam/steam/steamapps")
        try FileManager.default.createDirectory(at: apps.appendingPathComponent("common/GameX"),
                                                withIntermediateDirectories: true)
        try """
        "libraryfolders"
        {
        \t"0"\t{"path"\t"\(home.appendingPathComponent(".steam/steam").path)"}
        }
        """.write(to: apps.appendingPathComponent("libraryfolders.vdf"),
                  atomically: true, encoding: .utf8)
        try """
        "AppState"
        {
        \t"appid"\t\t"100"\n\t"name"\t\t"GameX"\n\t"installdir"\t\t"GameX"
        }
        """.write(to: apps.appendingPathComponent("appmanifest_100.acf"),
                  atomically: true, encoding: .utf8)
        return home
    }

    func testFindsGame() throws {
        let home = try makeSteam()
        let games = SteamDetector().games(home: home)
        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games[0].name, "GameX")
        XCTAssertEqual(games[0].appID, "100")
    }

    func testNoSteamEmpty() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        XCTAssertTrue(SteamDetector().games(home: home).isEmpty)
    }
}

final class DebugToolsTests: XCTestCase {
    func testLogStoreCapAndFilter() {
        var store = LogStore()
        store.capacity = 3
        for i in 0..<5 {
            store.append(RunRecord(date: Date(), bottle: "b", program: "p\(i)", args: [],
                                   exitCode: i % 2 == 0 ? 0 : 1, logTail: "t"))
        }
        XCTAssertEqual(store.records.count, 3)
        XCTAssertEqual(store.filtered(failuresOnly: true).count, 2)
    }

    func testBundleRenders() {
        let bottle = Bottle(name: "b", url: URL(fileURLWithPath: "/tmp/b"), wineVersion: "9.0")
        let md = DebugBundle.render(
            bottle: bottle,
            records: [RunRecord(date: Date(timeIntervalSince1970: 0), bottle: "b",
                                program: "n.exe", args: [], exitCode: 1, logTail: "boom")],
            wineVersion: "9.0", os: "TestOS 1.0")
        XCTAssertTrue(md.contains("n.exe") && md.contains("boom") && md.contains("TestOS"))
    }

    func testUpdateCheck() throws {
        let json = """
        [{"tag_name":"v0.2.0"},{"tag_name":"v0.1.0"}]
        """.data(using: .utf8)!
        XCTAssertEqual(UpdateCheck.parseTags(json), ["v0.2.0", "v0.1.0"])
        XCTAssertTrue(UpdateCheck.isNewer(latest: "v0.2.0", than: "0.1.0"))
        XCTAssertFalse(UpdateCheck.isNewer(latest: "0.1.0", than: "v0.2.0"))
        XCTAssertEqual(UpdateCheck.parseTags(Data("nope".utf8)), [])
    }
}
