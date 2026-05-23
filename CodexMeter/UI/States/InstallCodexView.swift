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
            Label("Codex CLI not found", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text("CodexMeter relies on the official Codex CLI. Install it with one of the following:")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                CommandRow("brew install codex")
                CommandRow("npm i -g @openai/codex")
            }

            Text("After installing, click Check Again.")
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
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy")
        }
    }
}
