//
//  NotificationSettingsView.swift
//  CodexMeter
//

import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var appState: AppState

    private let availableThresholds = [50, 75, 90, 95, 100]

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Enable notifications", isOn: Binding(
                    get: { appState.settings.notificationsEnabled },
                    set: { newValue in
                        appState.updateSetting { $0.notificationsEnabled = newValue }
                        if newValue {
                            Task { await NotificationService.shared.requestPermission() }
                        }
                    }
                ))
            }

            Section("Thresholds") {
                ForEach(availableThresholds, id: \.self) { threshold in
                    Toggle("Alert at \(threshold)%", isOn: Binding(
                        get: { appState.settings.notificationThresholds.contains(threshold) },
                        set: { isOn in
                            appState.updateSetting { settings in
                                var set = Set(settings.notificationThresholds)
                                if isOn { set.insert(threshold) } else { set.remove(threshold) }
                                settings.notificationThresholds = Array(set).sorted()
                            }
                        }
                    ))
                    .disabled(!appState.settings.notificationsEnabled)
                }
                Text("CodexMeter sends at most one notification per threshold per usage window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
