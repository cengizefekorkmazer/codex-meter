//
//  AppearanceSettingsView.swift
//  CodexMeter
//

import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            Section("Menu bar display") {
                Picker("Mode", selection: Binding(
                    get: { appState.settings.displayMode },
                    set: { newValue in appState.updateSetting { $0.displayMode = newValue } }
                )) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text("Detailed mode shows both 5-hour and weekly windows in the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
