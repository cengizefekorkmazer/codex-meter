//
//  ApiKeyEntryView.swift
//  CodexMeter
//

import SwiftUI

struct ApiKeyEntryView: View {
    @State private var apiKey: String = ""
    @State private var isSubmitting = false
    var errorMessage: String?
    var onCancel: () -> Void
    var onSubmit: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Sign in with an API key", systemImage: "key")
                .font(.headline)

            Text("Paste an OpenAI API key. The Codex app stores it on your Mac — CodexMeter never reads or saves it directly.")
                .font(.callout)
                .foregroundStyle(.secondary)

            SecureField("sk-...", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .onSubmit(submit)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text("You can create a key at platform.openai.com/api-keys.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)

            HStack {
                Button("Cancel", role: .cancel, action: onCancel)
                Spacer()
                Button("Sign in", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedKey.isEmpty || isSubmitting)
            }
        }
        .padding(16)
    }

    private var trimmedKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        let key = trimmedKey
        guard !key.isEmpty, !isSubmitting else { return }
        isSubmitting = true
        onSubmit(key)
    }
}
