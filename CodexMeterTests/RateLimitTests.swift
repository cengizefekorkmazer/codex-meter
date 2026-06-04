//
//  RateLimitTests.swift
//  CodexMeterTests
//

import XCTest
@testable import CodexMeter

final class RateLimitWindowTests: XCTestCase {
    private let decoder = JSONDecoder()

    func test_decodes_all_fields_and_converts_resetsAt_from_epoch_seconds() throws {
        let json = #"{"usedPercent": 31, "windowDurationMins": 300, "resetsAt": 1779582851}"#
        let window = try decoder.decode(RateLimitWindow.self, from: Data(json.utf8))

        XCTAssertEqual(window.usedPercent, 31)
        XCTAssertEqual(window.windowDurationMins, 300)
        // 1779582851 → May 2026
        XCTAssertNotNil(window.resetsAt)
        XCTAssertEqual(Int(window.resetsAt!.timeIntervalSince1970), 1779582851)
    }

    func test_treats_missing_optional_fields_as_nil() throws {
        let json = #"{"usedPercent": 0}"#
        let window = try decoder.decode(RateLimitWindow.self, from: Data(json.utf8))

        XCTAssertEqual(window.usedPercent, 0)
        XCTAssertNil(window.windowDurationMins)
        XCTAssertNil(window.resetsAt)
    }

    func test_encodes_resetsAt_back_to_epoch_seconds() throws {
        let window = RateLimitWindow(
            usedPercent: 42,
            windowDurationMins: 10080,
            resetsAt: Date(timeIntervalSince1970: 1780423818)
        )
        let data = try JSONEncoder().encode(window)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(dict["usedPercent"] as? Int, 42)
        XCTAssertEqual(dict["windowDurationMins"] as? Int, 10080)
        XCTAssertEqual(dict["resetsAt"] as? Int, 1780423818)
    }
}

final class RateLimitsReadResultTests: XCTestCase {
    private let decoder = JSONDecoder()

    /// Captured verbatim from `account/rateLimits/read` against codex 0.133.0.
    private let livePayload = #"""
    {
      "rateLimits": {
        "limitId": "codex",
        "limitName": null,
        "primary":   {"usedPercent": 1, "windowDurationMins": 300,   "resetsAt": 1779582851},
        "secondary": {"usedPercent": 0, "windowDurationMins": 10080, "resetsAt": 1780169651},
        "credits": {"hasCredits": false, "unlimited": false, "balance": "0"},
        "planType": "plus",
        "rateLimitReachedType": null
      },
      "rateLimitsByLimitId": {
        "codex": {
          "limitId": "codex",
          "limitName": null,
          "primary":   {"usedPercent": 1, "windowDurationMins": 300,   "resetsAt": 1779582851},
          "secondary": {"usedPercent": 0, "windowDurationMins": 10080, "resetsAt": 1780169651},
          "credits": {"hasCredits": false, "unlimited": false, "balance": "0"},
          "planType": "plus",
          "rateLimitReachedType": null
        }
      }
    }
    """#

    func test_decodes_live_payload_end_to_end() throws {
        let result = try decoder.decode(RateLimitsReadResult.self, from: Data(livePayload.utf8))

        XCTAssertEqual(result.rateLimits.limitId, "codex")
        XCTAssertEqual(result.rateLimits.planType, "plus")
        XCTAssertNil(result.rateLimits.rateLimitReachedType)
        XCTAssertEqual(result.rateLimits.credits?.balance, "0")
        XCTAssertEqual(result.rateLimits.credits?.hasCredits, false)
        XCTAssertEqual(result.rateLimits.primary?.usedPercent, 1)
        XCTAssertEqual(result.rateLimits.primary?.windowDurationMins, 300)
        XCTAssertEqual(result.rateLimits.secondary?.windowDurationMins, 10080)
    }

    func test_buckets_prefers_rateLimitsByLimitId_when_present() throws {
        let result = try decoder.decode(RateLimitsReadResult.self, from: Data(livePayload.utf8))
        XCTAssertEqual(result.buckets.count, 1)
        XCTAssertEqual(result.buckets.first?.limitId, "codex")
    }

    func test_buckets_falls_back_to_rateLimits_when_byLimitId_absent() throws {
        let json = #"""
        {
          "rateLimits": {
            "limitId": "codex",
            "primary": {"usedPercent": 5},
            "credits": {"hasCredits": false, "unlimited": false, "balance": "0"}
          }
        }
        """#
        let result = try decoder.decode(RateLimitsReadResult.self, from: Data(json.utf8))
        XCTAssertNil(result.rateLimitsByLimitId)
        XCTAssertEqual(result.buckets.count, 1)
        XCTAssertEqual(result.buckets.first?.primary?.usedPercent, 5)
    }

    func test_buckets_falls_back_to_rateLimits_when_byLimitId_is_empty() throws {
        let json = #"""
        {
          "rateLimits": {"limitId": "codex"},
          "rateLimitsByLimitId": {}
        }
        """#
        let result = try decoder.decode(RateLimitsReadResult.self, from: Data(json.utf8))
        XCTAssertEqual(result.buckets.count, 1)
        XCTAssertEqual(result.buckets.first?.limitId, "codex")
    }

    func test_buckets_are_sorted_by_limitId() throws {
        let json = #"""
        {
          "rateLimits": {"limitId": "codex"},
          "rateLimitsByLimitId": {
            "zebra": {"limitId": "zebra"},
            "alpha": {"limitId": "alpha"},
            "codex": {"limitId": "codex"}
          }
        }
        """#
        let result = try decoder.decode(RateLimitsReadResult.self, from: Data(json.utf8))
        XCTAssertEqual(result.buckets.map(\.limitId), ["alpha", "codex", "zebra"])
    }
}
