//
//  ThresholdNotifier.swift
//  CodexMeter
//
//  Pure throttling logic for usage-threshold notifications. Owns no UI and no
//  UNUserNotificationCenter calls — those live in `NotificationService` which
//  uses this type. Keeping the math separate makes it cheap to unit-test.
//

import Foundation

/// One notification the throttler thinks should be emitted.
struct ThresholdCrossing: Equatable {
    let bucketId: String
    /// "5h" or "weekly", used to label the notification.
    let kind: String
    let usedPercent: Int
    let threshold: Int
    let resetsAt: Date?
}

struct ThresholdNotifier {
    /// Per `bucketKey`, the `resetsAt` epoch we last observed and which
    /// thresholds we've already fired for that window.
    private struct WindowState: Equatable {
        var resetsAtEpoch: Int
        var firedThresholds: Set<Int>
    }
    private var state: [String: WindowState] = [:]

    /// Inspect a fresh set of snapshots and return any threshold crossings
    /// the caller hasn't been told about yet. Mutates internal state so the
    /// same crossing isn't reported twice within the same usage window.
    mutating func crossings(
        snapshots: [RateLimitSnapshot],
        thresholds: [Int]
    ) -> [ThresholdCrossing] {
        guard !thresholds.isEmpty else { return [] }
        let sorted = thresholds.sorted()

        var emitted: [ThresholdCrossing] = []
        for snapshot in snapshots {
            let bucketId = snapshot.limitId ?? "default"
            if let crossing = check(window: snapshot.primary,
                                    kind: "5h",
                                    bucketId: bucketId,
                                    thresholds: sorted) {
                emitted.append(crossing)
            }
            if let crossing = check(window: snapshot.secondary,
                                    kind: "weekly",
                                    bucketId: bucketId,
                                    thresholds: sorted) {
                emitted.append(crossing)
            }
        }
        return emitted
    }

    /// Clear all remembered state. Mainly useful in tests.
    mutating func reset() { state.removeAll() }

    // MARK: - Private

    private mutating func check(
        window: RateLimitWindow?,
        kind: String,
        bucketId: String,
        thresholds: [Int]
    ) -> ThresholdCrossing? {
        guard let window else { return nil }
        let key = "\(bucketId).\(kind)"
        let resetEpoch = window.resetsAt.map { Int($0.timeIntervalSince1970) } ?? 0

        var current = state[key] ?? WindowState(resetsAtEpoch: resetEpoch, firedThresholds: [])
        if current.resetsAtEpoch != resetEpoch {
            current = WindowState(resetsAtEpoch: resetEpoch, firedThresholds: [])
        }

        let unseenCrossed = thresholds
            .filter { window.usedPercent >= $0 && !current.firedThresholds.contains($0) }

        var crossing: ThresholdCrossing?
        if let highest = unseenCrossed.max() {
            crossing = ThresholdCrossing(
                bucketId: bucketId,
                kind: kind,
                usedPercent: window.usedPercent,
                threshold: highest,
                resetsAt: window.resetsAt
            )
            for t in unseenCrossed { current.firedThresholds.insert(t) }
        }

        state[key] = current
        return crossing
    }
}
