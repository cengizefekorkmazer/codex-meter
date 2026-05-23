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

    /// Per `bucketWindowKey`, the resetsAt epoch we last saw and which
    /// thresholds we've already fired for that window.
    private struct WindowState {
        var resetsAtEpoch: Int
        var firedThresholds: Set<Int>
    }
    private var state: [String: WindowState] = [:]

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
        guard !thresholds.isEmpty else { return }
        let sortedThresholds = thresholds.sorted()

        for snapshot in snapshots {
            check(window: snapshot.primary,
                  kind: "5h",
                  bucketId: snapshot.limitId ?? "default",
                  thresholds: sortedThresholds)
            check(window: snapshot.secondary,
                  kind: "weekly",
                  bucketId: snapshot.limitId ?? "default",
                  thresholds: sortedThresholds)
        }
    }

    private func check(window: RateLimitWindow?, kind: String, bucketId: String, thresholds: [Int]) {
        guard let window else { return }
        let key = "\(bucketId).\(kind)"
        let resetEpoch = window.resetsAt.map { Int($0.timeIntervalSince1970) } ?? 0

        var current = state[key] ?? WindowState(resetsAtEpoch: resetEpoch, firedThresholds: [])
        // Window rolled over — drop the fired set so the user gets notified
        // again in the new window.
        if current.resetsAtEpoch != resetEpoch {
            current = WindowState(resetsAtEpoch: resetEpoch, firedThresholds: [])
        }

        // Fire the highest threshold the user has crossed but hasn't seen yet.
        // (No point sending 75% and 90% back-to-back when both fired together.)
        let unseenCrossed = thresholds
            .filter { window.usedPercent >= $0 && !current.firedThresholds.contains($0) }

        if let highest = unseenCrossed.max() {
            send(usedPercent: window.usedPercent,
                 threshold: highest,
                 kind: kind,
                 resetsAt: window.resetsAt)
            for t in unseenCrossed { current.firedThresholds.insert(t) }
        }

        state[key] = current
    }

    private func send(usedPercent: Int, threshold: Int, kind: String, resetsAt: Date?) {
        let content = UNMutableNotificationContent()
        let label = kind == "5h" ? "5-hour" : "weekly"
        content.title = "Codex usage at \(usedPercent)%"
        if let resetsAt {
            let formatter = RelativeDateTimeFormatter()
            content.body = "Your \(label) limit crossed \(threshold)%. Resets \(formatter.localizedString(for: resetsAt, relativeTo: Date()))."
        } else {
            content.body = "Your \(label) limit crossed \(threshold)%."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "codex.\(kind).\(threshold).\(Int(Date().timeIntervalSince1970))",
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
