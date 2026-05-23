//
//  SignedOutView.swift
//  CodexMeter
//

import SwiftUI

struct SignedOutView: View {
    var onSignInWithChatGPT: () -> Void
    var onUseDeviceCode: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Not signed in", systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.headline)

            Text("Sign in to your ChatGPT account to read your Codex usage. CodexMeter doesn't see your tokens — the local Codex app-server handles authentication.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Sign in with ChatGPT", action: onSignInWithChatGPT)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .frame(maxWidth: .infinity)

            Button("Use device code instead", action: onUseDeviceCode)
                .buttonStyle(.borderless)

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}
