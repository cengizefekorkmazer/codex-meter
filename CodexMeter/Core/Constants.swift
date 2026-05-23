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

    enum UI {
        static let popoverWidth: CGFloat = 380
        static let popoverHeight: CGFloat = 420
        static let menuBarIconSize: CGFloat = 18
    }
}
