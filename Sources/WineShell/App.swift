import Foundation

#if canImport(SwiftUI)
import SwiftUI
import WineKit

/// App state: bottle library + run log. Thin shell over WineKit — no logic here.
@MainActor
final class AppState: ObservableObject {
    @Published var bottles: [String] = []
    @Published var log = LogStore()
    @Published var status: String = "idle"

    let store: BottleStore
    var wineURL: URL?
    var wineVersion: String = "unknown"

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.store = BottleStore(root: home.appendingPathComponent("wine-shell/bottles"))
        refresh()
    }

    func refresh() {
        bottles = (try? store.list()) ?? []
    }

    func createBottle(name: String) {
        do {
            _ = try store.create(name: name, wineVersion: wineVersion)
            refresh()
        } catch { status = "create failed: \(error)" }
    }

    func run(program: Program, bottle: Bottle, wineDEBUG channels: String) async {
        guard let wineURL else { status = "set Wine runtime first (Settings)"; return }
        status = "running \(program.name)…"
        let launcher = LocalWineLauncher(wineURL: wineURL)
        var env = WineEnvironment.build(bottle: bottle, program: program)
        if !channels.isEmpty { env["WINEDEBUG"] = channels }
        do {
            let result = try await launcher.run(
                args: [program.exePath] + program.args, env: env, timeout: 600)
            log.append(RunRecord(date: Date(), bottle: bottle.name, program: program.name,
                                 args: program.args, exitCode: result.exitCode,
                                 logTail: result.logTail))
            status = "exit \(result.exitCode)"
        } catch {
            status = "failed: \(error)"
        }
    }
}

@main
struct WineShellApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            BottleListView()
                .environmentObject(state)
                .frame(minWidth: 640, minHeight: 420)
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Export debug bundle") {
                    let b = DebugBundle.render(
                        bottle: (try? state.store.open(name: state.bottles.first ?? "",
                                                       currentWineVersion: state.wineVersion))
                            ?? Bottle(name: "-", url: URL(fileURLWithPath: "/tmp"),
                                      wineVersion: state.wineVersion),
                        records: state.log.records,
                        wineVersion: state.wineVersion,
                        os: ProcessInfo.processInfo.operatingSystemVersionString)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(b, forType: .string)
                    state.status = "bundle copied to clipboard"
                }
            }
        }
    }
}

struct BottleListView: View {
    @EnvironmentObject var state: AppState
    @State private var newName = ""
    @State private var selection: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(state.bottles, id: \.self) { name in
                    Label(name, systemImage: "archivebox").tag(name as String?)
                }
            }
            .navigationTitle("Bottles")
            .toolbar {
                HStack {
                    TextField("New bottle", text: $newName)
                    Button("Create") {
                        state.createBottle(name: newName)
                        newName = ""
                    }.disabled(newName.isEmpty)
                }
            }
        } detail: {
            if let name = selection,
               let bottle = try? state.store.open(name: name, currentWineVersion: state.wineVersion) {
                BottleDetailView(bottle: bottle)
            } else {
                Text("Select a bottle").foregroundStyle(.secondary)
            }
        }
        .overlay(alignment: .bottom) { Text(state.status).font(.caption).padding(4) }
    }
}

struct BottleDetailView: View {
    @EnvironmentObject var state: AppState
    let bottle: Bottle
    @State private var exePath = ""
    @State private var showRun = false

    var body: some View {
        Form {
            Section("Bottle") {
                LabeledContent("Backend", value: bottle.backend.rawValue)
                LabeledContent("Prefix", value: bottle.url.path)
            }
            Section("Run program") {
                TextField(".exe path (C: or host path)", text: $exePath)
                Button("Run with Options…") { showRun = true }.disabled(exePath.isEmpty)
            }
            Section("Recent runs") {
                ForEach(state.log.filtered(bottle: bottle.name).suffix(5).reversed(), id: \.date) { r in
                    HStack {
                        Image(systemName: r.exitCode == 0 ? "checkmark.circle" : "xmark.circle")
                        Text(r.program)
                        Spacer()
                        Text("exit \(r.exitCode)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(bottle.name)
        .sheet(isPresented: $showRun) {
            RunOptionsView(bottle: bottle,
                           program: Program(name: URL(fileURLWithPath: exePath).lastPathComponent,
                                            exePath: exePath))
        }
    }
}

#else
// Linux/Windows build: GUI needs macOS. Core stays fully usable + tested.
@main
struct WineShellLinuxMain {
    static func main() {
        print("wine-shell GUI requires macOS — use WineKit as a library here.")
    }
}
#endif
