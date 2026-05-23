//
//  AppState.swift
//  CodexMeter
//

import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var account: AccountState = .unknown
    @Published var snapshots: [RateLimitSnapshot] = []
    @Published var lastUpdated: Date?
    @Published var connection: ConnectionState = .disconnected
    @Published var error: AppError?

    init() {
        loadMockData()
    }

    /// Phase 1 only: seed the UI from the live payload captured during Phase 0
    /// so the menu bar / popover have something to render. Phase 2 replaces
    /// this with real `account/rateLimits/read` results.
    private func loadMockData() {
        account = .signedIn(email: "you@example.com", planType: "plus", accountType: "chatgpt")

        let now = Date()
        snapshots = [
            RateLimitSnapshot(
                limitId: "codex",
                limitName: nil,
                primary: RateLimitWindow(
                    usedPercent: 31,
                    windowDurationMins: 300,
                    resetsAt: now.addingTimeInterval(60 * 60 * 2 + 60 * 14)
                ),
                secondary: RateLimitWindow(
                    usedPercent: 12,
                    windowDurationMins: 10080,
                    resetsAt: now.addingTimeInterval(60 * 60 * 24 * 5)
                ),
                credits: nil,
                planType: "plus",
                rateLimitReachedType: nil
            )
        ]
        lastUpdated = now
        connection = .connected
    }

    var primaryUsage: Double {
        snapshots.first?.primary.map { Double($0.usedPercent) } ?? 0
    }
}
