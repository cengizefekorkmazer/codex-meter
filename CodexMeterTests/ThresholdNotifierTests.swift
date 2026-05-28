//
//  ThresholdNotifierTests.swift
//  CodexMeterTests
//

import XCTest
@testable import CodexMeter

final class ThresholdNotifierTests: XCTestCase {
    private var notifier = ThresholdNotifier()
    private let resetAt = Date(timeIntervalSince1970: 1_779_582_851)

    override func setUp() {
        super.setUp()
        notifier = ThresholdNotifier()
    }

    // MARK: - Helpers

    private func snapshot(
        bucketId: String = "codex",
        primaryPercent: Int? = nil,
        secondaryPercent: Int? = nil,
        primaryResetsAt: Date? = nil,
        secondaryResetsAt: Date? = nil
    ) -> RateLimitSnapshot {
        let primary = primaryPercent.map {
            RateLimitWindow(usedPercent: $0, windowDurationMins: 300,
                            resetsAt: primaryResetsAt ?? resetAt)
        }
        let secondary = secondaryPercent.map {
            RateLimitWindow(usedPercent: $0, windowDurationMins: 10080,
                            resetsAt: secondaryResetsAt ?? resetAt)
        }
        return RateLimitSnapshot(
            limitId: bucketId,
            limitName: nil,
            primary: primary,
            secondary: secondary,
            credits: nil,
            planType: "plus",
            rateLimitReachedType: nil
        )
    }

    // MARK: - Tests

    func test_emits_nothing_when_thresholds_list_is_empty() {
        let crossings = notifier.crossings(
            snapshots: [snapshot(primaryPercent: 99)],
            thresholds: []
        )
        XCTAssertEqual(crossings, [])
    }

    func test_emits_nothing_below_lowest_threshold() {
        let crossings = notifier.crossings(
            snapshots: [snapshot(primaryPercent: 30)],
            thresholds: [75, 90, 95]
        )
        XCTAssertEqual(crossings, [])
    }

    func test_emits_single_crossing_at_lowest_threshold_just_crossed() {
        let crossings = notifier.crossings(
            snapshots: [snapshot(primaryPercent: 80)],
            thresholds: [75, 90, 95]
        )
        XCTAssertEqual(crossings.count, 1)
        XCTAssertEqual(crossings.first?.threshold, 75)
        XCTAssertEqual(crossings.first?.usedPercent, 80)
        XCTAssertEqual(crossings.first?.kind, "5h")
    }

    func test_collapses_multiple_thresholds_into_the_highest_when_crossed_at_once() {
        // Usage jumps straight from 30% to 96% — user only needs the 95% alert,
        // not 75% + 90% + 95% in rapid succession.
        let crossings = notifier.crossings(
            snapshots: [snapshot(primaryPercent: 96)],
            thresholds: [75, 90, 95]
        )
        XCTAssertEqual(crossings.count, 1)
        XCTAssertEqual(crossings.first?.threshold, 95)
    }

    func test_does_not_re_emit_threshold_within_same_window() {
        let snap = snapshot(primaryPercent: 80)
        _ = notifier.crossings(snapshots: [snap], thresholds: [75, 90])
        let second = notifier.crossings(snapshots: [snap], thresholds: [75, 90])
        XCTAssertEqual(second, [])
    }

    func test_emits_next_threshold_when_usage_rises_in_same_window() {
        _ = notifier.crossings(snapshots: [snapshot(primaryPercent: 76)],
                               thresholds: [75, 90, 95])
        let rising = notifier.crossings(snapshots: [snapshot(primaryPercent: 91)],
                                        thresholds: [75, 90, 95])
        XCTAssertEqual(rising.count, 1)
        XCTAssertEqual(rising.first?.threshold, 90)
    }

    func test_window_rollover_clears_fired_thresholds() {
        _ = notifier.crossings(snapshots: [snapshot(primaryPercent: 80)],
                               thresholds: [75])

        let newWindow = snapshot(primaryPercent: 80,
                                 primaryResetsAt: resetAt.addingTimeInterval(60))
        let crossings = notifier.crossings(snapshots: [newWindow],
                                           thresholds: [75])
        XCTAssertEqual(crossings.count, 1)
        XCTAssertEqual(crossings.first?.threshold, 75)
    }

    func test_primary_and_secondary_windows_are_tracked_independently() {
        let crossings = notifier.crossings(
            snapshots: [snapshot(primaryPercent: 80, secondaryPercent: 92)],
            thresholds: [75, 90]
        )
        XCTAssertEqual(crossings.count, 2)
        XCTAssertEqual(Set(crossings.map(\.kind)), ["5h", "weekly"])
    }

    func test_different_buckets_are_tracked_independently() {
        let snaps = [
            snapshot(bucketId: "codex", primaryPercent: 80),
            snapshot(bucketId: "other", primaryPercent: 80),
        ]
        let crossings = notifier.crossings(snapshots: snaps, thresholds: [75])
        XCTAssertEqual(crossings.count, 2)
        XCTAssertEqual(Set(crossings.map(\.bucketId)), ["codex", "other"])
    }

    func test_snapshot_without_windows_emits_nothing() {
        let snap = RateLimitSnapshot(
            limitId: "codex", limitName: nil,
            primary: nil, secondary: nil,
            credits: nil, planType: "plus", rateLimitReachedType: nil
        )
        XCTAssertEqual(notifier.crossings(snapshots: [snap], thresholds: [75]), [])
    }

    func test_reset_drops_all_remembered_state() {
        let snap = snapshot(primaryPercent: 80)
        _ = notifier.crossings(snapshots: [snap], thresholds: [75])
        notifier.reset()
        let crossings = notifier.crossings(snapshots: [snap], thresholds: [75])
        XCTAssertEqual(crossings.count, 1)
    }
}
