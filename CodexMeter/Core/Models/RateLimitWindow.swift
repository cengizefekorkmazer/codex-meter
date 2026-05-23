//
//  RateLimitWindow.swift
//  CodexMeter
//

import Foundation

/// One usage window within a rate-limit snapshot.
///
/// Mirrors `RateLimitWindow` from the app-server JSON Schema.
/// - `usedPercent` is an integer 0–100 (we keep it as Int and convert only at
///   the UI boundary).
/// - `resetsAt` is decoded from a Unix epoch *seconds* timestamp.
struct RateLimitWindow: Codable, Equatable, Hashable {
    let usedPercent: Int
    let windowDurationMins: Int?
    let resetsAt: Date?

    init(usedPercent: Int, windowDurationMins: Int?, resetsAt: Date?) {
        self.usedPercent = usedPercent
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }

    private enum CodingKeys: String, CodingKey {
        case usedPercent
        case windowDurationMins
        case resetsAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.usedPercent = try c.decode(Int.self, forKey: .usedPercent)
        self.windowDurationMins = try c.decodeIfPresent(Int.self, forKey: .windowDurationMins)
        if let epochSeconds = try c.decodeIfPresent(Int64.self, forKey: .resetsAt) {
            self.resetsAt = Date(timeIntervalSince1970: TimeInterval(epochSeconds))
        } else {
            self.resetsAt = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(usedPercent, forKey: .usedPercent)
        try c.encodeIfPresent(windowDurationMins, forKey: .windowDurationMins)
        if let resetsAt {
            try c.encode(Int64(resetsAt.timeIntervalSince1970), forKey: .resetsAt)
        }
    }
}
