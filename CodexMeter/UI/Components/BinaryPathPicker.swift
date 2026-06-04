//
//  BinaryPathPicker.swift
//  CodexMeter
//

import AppKit

/// Presents an open panel for choosing the `codex` executable manually — the
/// escape hatch when auto-detection fails (unusual install location).
enum BinaryPathPicker {
    @MainActor
    static func choose() -> String? {
        let panel = NSOpenPanel()
        panel.title = "Choose the codex executable"
        panel.prompt = "Choose"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        // codex lives in bin dirs that are normally hidden in the panel.
        panel.showsHiddenFiles = true
        panel.treatsFilePackagesAsDirectories = true
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url.path
    }
}
