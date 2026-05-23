//
//  CodexMeterApp.swift
//  CodexMeter
//
//  Copyright (c) 2026 codex-meter contributors.
//  Licensed under the MIT License.
//

import SwiftUI

@main
struct CodexMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
