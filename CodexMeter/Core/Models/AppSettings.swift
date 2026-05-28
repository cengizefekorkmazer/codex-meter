//
//  AppSettings.swift
//  CodexMeter
//

import Foundation

struct AppSettings: Codable, Equatable {
    var refreshIntervalSeconds: Int
    var displayMode: DisplayMode
    var launchAtLogin: Bool
    var customCodexBinaryPath: String
    var notificationsEnabled: Bool
    var notificationThresholds: [Int]
    var debugMode: Bool

    // Visibility toggles — let the user hide secondary readouts they don't
    // care about.
    var showFiveHourLimit: Bool
    var showWeeklyLimit: Bool
    var showCredits: Bool

    static let `default` = AppSettings(
        refreshIntervalSeconds: Int(Constants.Polling.defaultInterval),
        displayMode: .compact,
        launchAtLogin: false,
        customCodexBinaryPath: "",
        notificationsEnabled: true,
        notificationThresholds: [75, 90, 95],
        debugMode: false,
        showFiveHourLimit: true,
        showWeeklyLimit: true,
        showCredits: true
    )

    private static let storageKey = "CodexMeter.AppSettings.v1"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return .default
        }
        // Decode tolerantly so users with an older saved settings file don't
        // get reset to defaults when we add new fields.
        let decoder = JSONDecoder()
        if let s = try? decoder.decode(AppSettings.self, from: data) {
            return s
        }
        if let legacy = try? decoder.decode(LegacyAppSettings.self, from: data) {
            return legacy.upgraded()
        }
        return .default
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

/// Mirrors the pre-visibility-toggle settings shape. Used to upgrade users
/// who saved settings before `showFiveHourLimit` / `showWeeklyLimit` /
/// `showCredits` existed.
private struct LegacyAppSettings: Codable {
    var refreshIntervalSeconds: Int
    var displayMode: DisplayMode
    var launchAtLogin: Bool
    var customCodexBinaryPath: String
    var notificationsEnabled: Bool
    var notificationThresholds: [Int]
    var debugMode: Bool

    func upgraded() -> AppSettings {
        AppSettings(
            refreshIntervalSeconds: refreshIntervalSeconds,
            displayMode: displayMode,
            launchAtLogin: launchAtLogin,
            customCodexBinaryPath: customCodexBinaryPath,
            notificationsEnabled: notificationsEnabled,
            notificationThresholds: notificationThresholds,
            debugMode: debugMode,
            showFiveHourLimit: true,
            showWeeklyLimit: true,
            showCredits: true
        )
    }
}
