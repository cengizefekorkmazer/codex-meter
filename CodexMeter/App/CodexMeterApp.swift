//
//  CodexMeterApp.swift
//  CodexMeter
//

import SwiftUI

@main
struct CodexMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We deliberately omit a Settings { } scene — CodexMeter is a menu bar
        // accessory app, so settings live inside the popover (see PopoverView).
        // SwiftUI requires at least one Scene; an empty Settings scene is the
        // smallest non-window placeholder.
        Settings { EmptyView() }
    }
}
