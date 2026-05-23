//
//  ErrorView.swift
//  CodexMeter
//

import SwiftUI
import AppKit

struct ErrorView: View {
    let reason: String
    var onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Something went wrong", systemImage: "xmark.octagon.fill")
                .font(.headline)
                .foregroundStyle(.red)

            Text(reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Spacer(minLength: 0)

            HStack {
                Button("Retry", action: onRetry)
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
