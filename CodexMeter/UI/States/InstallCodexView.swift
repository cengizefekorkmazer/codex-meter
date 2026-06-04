//
//  InstallCodexView.swift
//  CodexMeter
//

import SwiftUI
import AppKit

struct InstallCodexView: View {
    var onRetry: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Set up Codex", systemImage: "wrench.and.screwdriver")
                .font(.headline)

            Text("CodexMeter shows your Codex usage, but it needs the official Codex app to be installed on your Mac first.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Open Terminal and run one of these:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                CommandRow("brew install codex")
                CommandRow("npm i -g @openai/codex")
            }

            Text("Then come back and click \"Check Again\".")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)

            HStack {
                Button("Check Again", action: onRetry)
                    .keyboardShortcut(.defaultAction)
                Spacer()
                Button("Quit", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
    }
}

private struct CommandRow: View {
    let command: String
    @State private var copied = false

    init(_ command: String) { self.command = command }

    var body: some View {
        HStack(spacing: 8) {
            Text(command)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help(copied ? "Copied" : "Copy")
        }
    }
}
