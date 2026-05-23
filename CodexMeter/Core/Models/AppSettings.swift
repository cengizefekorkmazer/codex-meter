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

    static let `default` = AppSettings(
        refreshIntervalSeconds: Int(Constants.Polling.defaultInterval),
        displayMode: .compact,
        launchAtLogin: false,
        customCodexBinaryPath: "",
        notificationsEnabled: true,
        notificationThresholds: [75, 90, 95],
        debugMode: false
    )

    private static let storageKey = "CodexMeter.AppSettings.v1"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return .default
        }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            return .default
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
