//
//  AppDelegate.swift
//  CodexMeter
//

import Cocoa
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var appState: AppState?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let state = AppState()
        appState = state

        statusItemController = StatusItemController(appState: state)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Phase 2 will tear down the JSON-RPC client and child process here.
    }
}
