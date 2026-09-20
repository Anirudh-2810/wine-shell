import XCTest
@testable import WineKit

final class WineEnvironmentTests: XCTestCase {
    func testBaseLayer() {
        let bottle = Bottle(name: "t", url: URL(fileURLWithPath: "/tmp/t"), wineVersion: "9.0")
        let env = WineEnvironment.build(bottle: bottle)
        XCTAssertEqual(env["WINEPREFIX"], "/tmp/t")
        XCTAssertEqual(env["WINEDEBUG"], "fixme-all")
        XCTAssertNil(env["WINEDLLOVERRIDES"]) // wined3d deploys nothing
    }

    func testBackendAndPrecedence() {
        let bottle = Bottle(name: "t", url: URL(fileURLWithPath: "/tmp/t"), wineVersion: "9.0",
                            backend: .dxvk, customEnv: ["DXVK_ASYNC": "0"])
        let program = Program(name: "p", exePath: "C:\\a.exe",
                              env: ["WINEDEBUG": "+relay"])
        let env = WineEnvironment.build(bottle: bottle, program: program)
        // program > bottle custom > backend > base
        XCTAssertEqual(env["WINEDEBUG"], "+relay")
        XCTAssertEqual(env["DXVK_ASYNC"], "0")
        XCTAssertTrue(env["WINEDLLOVERRIDES"]?.contains("d3d11=n,b") ?? false)
    }

    func testProgramBackendOverride() {
        let bottle = Bottle(name: "t", url: URL(fileURLWithPath: "/tmp/t"), wineVersion: "9.0",
                            backend: .wined3d)
        let program = Program(name: "p", exePath: "C:\\a.exe", backendOverride: .dxvk)
        let env = WineEnvironment.build(bottle: bottle, program: program)
        XCTAssertNotNil(env["WINEDLLOVERRIDES"])
    }
}

final class RecipeTests: XCTestCase {
    func testDecode() throws {
        let json = """
        {"name":"7-Zip","exePath":"C:\\\\Program Files\\\\7-Zip\\\\7zFM.exe",
         "installerArgs":[],"notes":"","needsReboot":false,
         "winetricksVerbs":[],"downloadURL":null}
        """
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        XCTAssertEqual(recipe.name, "7-Zip")
        XCTAssertFalse(recipe.needsReboot)
    }
}

final class RefusalTests: XCTestCase {
    func testClean() { XCTAssertNil(RefusalCheck.check(exeName: "notepad.exe")) }

    func testBlocked() {
        let refusal = RefusalCheck.check(exeName: "EasyAntiCheat_Setup.exe")
        XCTAssertNotNil(refusal)
        XCTAssertTrue(refusal?.suggestion.contains("VM") ?? false)
    }
}
