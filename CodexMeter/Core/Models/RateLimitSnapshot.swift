//
//  RateLimitSnapshot.swift
//  CodexMeter
//

import Foundation

/// One bucket of rate-limit information for a given `limitId`.
///
/// Returned by `account/rateLimits/read` (inside `rateLimitsByLimitId`) and
/// pushed by the `account/rateLimits/updated` notification.
struct RateLimitSnapshot: Codable, Equatable, Identifiable, Hashable {
    let limitId: String?
    let limitName: String?
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?
    let credits: RateLimitCredits?
    let planType: String?
    let rateLimitReachedType: String?

    var id: String { limitId ?? "default" }

    init(
        limitId: String?,
        limitName: String?,
        primary: RateLimitWindow?,
        secondary: RateLimitWindow?,
        credits: RateLimitCredits?,
        planType: String?,
        rateLimitReachedType: String?
    ) {
        self.limitId = limitId
        self.limitName = limitName
        self.primary = primary
        self.secondary = secondary
        self.credits = credits
        self.planType = planType
        self.rateLimitReachedType = rateLimitReachedType
    }
}

struct RateLimitCredits: Codable, Equatable, Hashable {
    let hasCredits: Bool
    let unlimited: Bool
    let balance: String
}

/// Result payload of `account/rateLimits/read`.
struct RateLimitsReadResult: Codable, Equatable {
    let rateLimits: RateLimitSnapshot
    let rateLimitsByLimitId: [String: RateLimitSnapshot]?

    /// Returns the canonical list of buckets, preferring `rateLimitsByLimitId`
    /// when present and falling back to the single-bucket `rateLimits` field.
    var buckets: [RateLimitSnapshot] {
        if let map = rateLimitsByLimitId, !map.isEmpty {
            return map.values.sorted { ($0.limitId ?? "") < ($1.limitId ?? "") }
        }
        return [rateLimits]
    }
}
