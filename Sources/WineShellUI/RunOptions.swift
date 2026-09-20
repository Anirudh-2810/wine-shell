import Foundation

#if canImport(SwiftUI)
import SwiftUI
import WineKit

/// CrossOver "Run with Options": args + env + backend + Wine channels + log view.
struct RunOptionsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    let bottle: Bottle
    @State var program: Program
    @State private var argsText = ""
    @State private var envText = ""
    @State private var channels = ""
    @State private var makeLog = true
    @State private var lastLog = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Program") {
                    LabeledContent("exe", value: program.exePath)
                    TextField("Arguments (space-separated)", text: $argsText)
                    TextField("Extra env (KEY=val, comma-separated)", text: $envText)
                }
                Section("Backend") {
                    Picker("Backend", selection: $program.backendOverride.orDefault(bottle.backend)) {
                        ForEach(GraphicsBackend.allCases, id: \.self) { b in
                            Text(b.rawValue).tag(b)
                        }
                    }
                    if bottle.backend == .d3dMetal || program.backendOverride == .d3dMetal {
                        Text("D3DMetal needs your Apple GPTK import first.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Section("Logging") {
                    Toggle("Create log file (console below)", isOn: $makeLog)
                    TextField("WINEDEBUG channels (blank = fixme-all)", text: $channels)
                }
                if makeLog && !lastLog.isEmpty {
                    Section("Log tail") {
                        ScrollView { Text(lastLog).font(.caption.monospaced()).textSelection(.enabled) }
                            .frame(minHeight: 120)
                    }
                }
            }
            .navigationTitle("Run with Options")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Run") {
                        Task {
                            program.args = argsText.split(separator: " ").map(String.init)
                            for pair in envText.split(separator: ",") {
                                let kv = pair.split(separator: "=", maxSplits: 1)
                                if kv.count == 2 {
                                    program.env[String(kv[0]).trimmingCharacters(in: .whitespaces)] =
                                        String(kv[1]).trimmingCharacters(in: .whitespaces)
                                }
                            }
                            await state.run(program: program, bottle: bottle, wineDEBUG: channels)
                            lastLog = state.log.records.last?.logTail ?? ""
                        }
                    }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 480)
    }
}

/// Debug console: run history + failure filter + bundle copy.
struct DebugConsoleView: View {
    @EnvironmentObject var state: AppState
    @State private var failuresOnly = false

    var body: some View {
        VStack {
            Toggle("Failures only", isOn: $failuresOnly)
            List(state.log.filtered(failuresOnly: failuresOnly).reversed(), id: \.date) { r in
                VStack(alignment: .leading) {
                    HStack {
                        Text(r.program).bold()
                        Spacer()
                        Text("exit \(r.exitCode)").font(.caption)
                    }
                    Text(r.logTail).font(.caption.monospaced()).lineLimit(3)
                        .foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
        }
        .padding()
    }
}

/// Binding helper: optional picker selection with a concrete default.
extension Binding where Value == GraphicsBackend? {
    func orDefault(_ dflt: GraphicsBackend) -> Binding<GraphicsBackend> {
        Binding<GraphicsBackend>(get: { wrappedValue ?? dflt }, set: { wrappedValue = $0 })
    }
}
#endif
