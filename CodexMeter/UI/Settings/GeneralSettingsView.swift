//
//  GeneralSettingsView.swift
//  CodexMeter
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct GeneralSettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { appState.settings.launchAtLogin },
                    set: { newValue in
                        appState.updateSetting { $0.launchAtLogin = newValue }
                        _ = LaunchAtLoginManager.setEnabled(newValue)
                    }
                ))
            }

            Section("Refresh") {
                Picker("Polling interval", selection: Binding(
                    get: { appState.settings.refreshIntervalSeconds },
                    set: { newValue in appState.updateSetting { $0.refreshIntervalSeconds = newValue } }
                )) {
                    Text("30 seconds (debug)").tag(30)
                    Text("1 minute").tag(60)
                    Text("5 minutes (default)").tag(300)
                    Text("15 minutes").tag(900)
                }
                Text("CodexMeter receives live push updates from the Codex app-server. This polling interval is the fallback when no push arrives.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Codex CLI") {
                TextField("Custom binary path", text: Binding(
                    get: { appState.settings.customCodexBinaryPath },
                    set: { newValue in appState.updateSetting { $0.customCodexBinaryPath = newValue } }
                ))
                .textFieldStyle(.roundedBorder)
                Text("Leave empty to use the codex on your PATH. Changes take effect on next reconnect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Diagnostics") {
                Toggle("Debug mode", isOn: Binding(
                    get: { appState.settings.debugMode },
                    set: { newValue in appState.updateSetting { $0.debugMode = newValue } }
                ))
                Text("Logs JSON-RPC traffic to ~/Library/Caches/CodexMeter/debug.log for troubleshooting. The log file never contains tokens.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Reveal log in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([DebugLogger.logURL])
                    }
                    .disabled(!FileManager.default.fileExists(atPath: DebugLogger.logURL.path))
                    Button("Export log…", action: exportDebugLog)
                        .disabled(!FileManager.default.fileExists(atPath: DebugLogger.logURL.path))
                }
            }
        }
        .formStyle(.grouped)
    }

    private func exportDebugLog() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "codexmeter-debug-\(Int(Date().timeIntervalSince1970)).log"
        panel.allowedContentTypes = [.log, .plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: DebugLogger.logURL, to: dest)
        } catch {
            print("GeneralSettingsView: export failed — \(error)")
        }
    }
}
