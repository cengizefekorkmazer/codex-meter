//
//  GeneralSettingsView.swift
//  CodexMeter
//

import SwiftUI

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
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("5 minutes").tag(300)
                    Text("15 minutes").tag(900)
                }
                Text("CodexMeter receives live push updates from the Codex app-server. This polling interval is the fallback when no push arrives.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Codex") {
                let path = appState.settings.customCodexBinaryPath
                HStack {
                    TextField(
                        "Custom codex path",
                        text: Binding(
                            get: { appState.settings.customCodexBinaryPath },
                            set: { appState.setCustomCodexBinaryPath($0) }
                        ),
                        prompt: Text("Auto-detected")
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.callout, design: .monospaced))

                    Button("Browse…") {
                        if let picked = BinaryPathPicker.choose() {
                            appState.setCustomCodexBinaryPath(picked)
                        }
                    }
                    if !path.isEmpty {
                        Button("Clear") { appState.setCustomCodexBinaryPath("") }
                    }
                }
                Text("Leave empty to auto-detect. Set this only if CodexMeter can't find your codex install (for example a custom npm or nvm location).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("What to show in the popover") {
                Toggle("5-Hour limit", isOn: Binding(
                    get: { appState.settings.showFiveHourLimit },
                    set: { newValue in appState.updateSetting { $0.showFiveHourLimit = newValue } }
                ))
                Toggle("7-Day limit", isOn: Binding(
                    get: { appState.settings.showWeeklyLimit },
                    set: { newValue in appState.updateSetting { $0.showWeeklyLimit = newValue } }
                ))
                Toggle("Credit balance", isOn: Binding(
                    get: { appState.settings.showCredits },
                    set: { newValue in appState.updateSetting { $0.showCredits = newValue } }
                ))
                Text("Credits only appear when your plan includes them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
