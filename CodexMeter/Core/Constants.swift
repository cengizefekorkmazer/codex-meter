//
//  Constants.swift
//  CodexMeter
//

import Foundation

enum Constants {
    enum Codex {
        static let binarySearchPaths: [String] = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        static let appServerArguments: [String] = [
            "app-server",
            "--listen",
            "stdio://"
        ]
        static let pinnedCliVersion = "0.133.0"
    }

    enum Polling {
        static let defaultInterval: TimeInterval = 300
        static let minInterval: TimeInterval = 30
        static let maxInterval: TimeInterval = 900
        static let debugInterval: TimeInterval = 30
    }

    enum Reconnect {
        /// Backoff delays in seconds. After exhausting the list we hold at the
        /// final value until either the user retries manually or the system
        /// notifies us of a wake event.
        static let backoffDelays: [TimeInterval] = [1, 2, 5, 10, 30]
    }

    enum WakeRecovery {
        /// Sleep durations beyond this threshold (seconds) are treated as
        /// "significant" — we discard cached snapshots and force a refresh on
        /// wake so the UI doesn't display stale data.
        static let significantSleepDuration: TimeInterval = 60
    }

    enum UI {
        static let popoverWidth: CGFloat = 380
        static let popoverHeight: CGFloat = 420
        static let menuBarIconSize: CGFloat = 18
    }
}
