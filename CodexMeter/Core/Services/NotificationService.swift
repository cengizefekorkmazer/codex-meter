//
//  NotificationService.swift
//  CodexMeter
//

import Foundation
import UserNotifications

/// Sends macOS notifications when rate-limit usage crosses configured
/// thresholds. Throttled per (bucket, window, threshold, resetsAt) so the
/// user receives at most one notification per threshold per usage window.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private var throttler = ThresholdNotifier()

    private init() {}

    func requestPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            print("NotificationService: permission request failed: \(error)")
        }
    }

    /// Inspect the latest snapshots and emit notifications for any newly
    /// crossed thresholds. Pass an empty thresholds array to suppress all
    /// notifications.
    func checkAndNotify(snapshots: [RateLimitSnapshot], thresholds: [Int]) {
        let crossings = throttler.crossings(snapshots: snapshots, thresholds: thresholds)
        for crossing in crossings {
            send(crossing)
        }
    }

    private func send(_ crossing: ThresholdCrossing) {
        let content = UNMutableNotificationContent()
        let label = crossing.kind == "5h" ? "5-hour" : "weekly"
        content.title = "Codex usage at \(crossing.usedPercent)%"
        if let resetsAt = crossing.resetsAt {
            let formatter = RelativeDateTimeFormatter()
            content.body = "Your \(label) limit crossed \(crossing.threshold)%. Resets \(formatter.localizedString(for: resetsAt, relativeTo: Date()))."
        } else {
            content.body = "Your \(label) limit crossed \(crossing.threshold)%."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "codex.\(crossing.kind).\(crossing.threshold).\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("NotificationService: post failed: \(error)")
            }
        }
    }
}
