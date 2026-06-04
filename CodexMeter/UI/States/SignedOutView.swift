//
//  SignedOutView.swift
//  CodexMeter
//

import SwiftUI

struct SignedOutView: View {
    var onSignInWithChatGPT: () -> Void
    var onUseDeviceCode: () -> Void
    var onUseApiKey: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Connect your account", systemImage: "person.crop.circle")
                .font(.headline)

            Text("Sign in with your ChatGPT account to see your Codex usage. CodexMeter never sees your password — sign-in happens through Codex itself.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Sign in with ChatGPT", action: onSignInWithChatGPT)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .frame(maxWidth: .infinity)

            HStack(spacing: 16) {
                Button("Sign in with a code", action: onUseDeviceCode)
                    .buttonStyle(.borderless)
                Button("Use an API key", action: onUseApiKey)
                    .buttonStyle(.borderless)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}
