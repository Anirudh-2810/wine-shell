// Spike0 — Phase 0 viability harness (RUN ON AN APPLE SILICON MAC).
// Proves: Swift Process → env passthrough → Wine under Rosetta → wrapper bundle → winecfg/notepad.
// Usage: swift Spike0/main.swift <wineBinDir> <bottleDir> <test>
//   <wineBinDir>  dir containing `wine64` (from Runbook step 3)
//   <bottleDir    empty dir for WINEPREFIX (created if missing)
//   <test>        winecfg | notepad
// Exit 0 = step proved. Non-zero = kill-criteria evidence, paste output in plan.

import Foundation

enum SpikeError: Error, CustomStringConvertible {
    case usage, timeout, launchFailed(String), badExit(Int32, String)
    var description: String {
        switch self {
        case .usage: return "usage: main.swift <wineBinDir> <bottleDir> <winecfg|notepad>"
        case .timeout: return "TIMEOUT: wineboot/process hung past 90s"
        case .launchFailed(let s): return "LAUNCH FAILED: \(s)"
        case .badExit(let c, let tail): return "EXIT \(c). log tail:\n\(tail)"
        }
    }
}

func run(_ exe: URL, args: [String], env: [String: String], timeout: TimeInterval) throws -> (Int32, String) {
    let p = Process()
    p.executableURL = exe
    p.arguments = args                       // argv array — never a shell string
    var e = ProcessInfo.processInfo.environment
    for (k, v) in env { e[k] = v }           // caller env wins
    p.environment = e
    let out = Pipe(), err = Pipe()
    p.standardOutput = out; p.standardError = err
    var buf = Data()
    let lock = NSLock()
    // Async drainage from day one — never blocking readToEnd (deadlock rule).
    out.fileHandleForReading.readabilityHandler = { h in
        let d = h.availableData; if !d.isEmpty { lock.lock(); buf.append(d); lock.unlock() }
    }
    err.fileHandleForReading.readabilityHandler = { h in
        let d = h.availableData; if !d.isEmpty { lock.lock(); buf.append(d); lock.unlock() }
    }
    do { try p.run() } catch { throw SpikeError.launchFailed("\(error)") }
    let deadline = Date().addingTimeInterval(timeout)
    while p.isRunning {
        if Date() > deadline { p.terminate(); sleep(2); if p.isRunning { p.interrupt() }
            throw SpikeError.timeout }
        Thread.sleep(forTimeInterval: 0.2)
    }
    out.fileHandleForReading.readabilityHandler = nil
    err.fileHandleForReading.readabilityHandler = nil
    lock.lock(); let tail = String(data: buf.suffix(2000), encoding: .utf8) ?? "<non-utf8>"
    lock.unlock()
    return (p.terminationStatus, tail)
}

let a = CommandLine.arguments
guard a.count == 4, ["winecfg", "notepad"].contains(a[3]) else { throw SpikeError.usage }
let wineBin = URL(fileURLWithPath: a[1]), bottle = URL(fileURLWithPath: a[2])
let fm = FileManager.default
try fm.createDirectory(at: bottle, withIntermediateDirectories: true)
let wine64 = wineBin.appendingPathComponent("wine64")
guard fm.isExecutableFile(atPath: wine64.path) else {
    throw SpikeError.launchFailed("\(wine64.path) missing/not executable (Rosetta? quarantine? see Runbook)")
}
let baseEnv = [
    "WINEPREFIX": bottle.path,
    "WINEDEBUG": "fixme-all",
    "WINEESYNC": "1",
]
// Step 1: init the bottle.
print("[spike] wineboot --init …")
let (c1, t1) = try run(wine64, args: ["wineboot", "--init"], env: baseEnv, timeout: 90)
guard c1 == 0 else { throw SpikeError.badExit(c1, t1) }
print("[spike] bottle init OK")
// Step 2: run the test program.
print("[spike] running \(a[3]) … (interact, then close it)")
let (c2, t2) = try run(wine64, args: [a[3]], env: baseEnv, timeout: 120)
print("[spike] \(a[3]) exited \(c2). tail:\n\(t2)")
print("[spike] PROVED")
