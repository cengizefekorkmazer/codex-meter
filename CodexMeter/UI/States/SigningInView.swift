//
//  SigningInView.swift
//  CodexMeter
//

import SwiftUI
import AppKit

struct SigningInView: View {
    let prompt: LoginPrompt
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Signing in…", systemImage: "key.fill")
                .font(.headline)

            switch prompt {
            case .chatgpt(let authUrl, _):
                Text("Complete the sign-in flow in your browser. CodexMeter will pick up the new credentials automatically.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let authUrl {
                    Button("Reopen browser") {
                        NSWorkspace.shared.open(authUrl)
                    }
                    .controlSize(.small)
                }

            case .deviceCode(let userCode, let verificationUrl, _):
                VStack(alignment: .leading, spacing: 8) {
                    Text("Go to:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let verificationUrl {
                        HStack(spacing: 8) {
                            Link(verificationUrl.absoluteString, destination: verificationUrl)
                                .font(.system(.callout, design: .monospaced))
                            CopyButton(text: verificationUrl.absoluteString)
                        }
                    }
                    Text("And enter the code:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    HStack(spacing: 8) {
                        Text(userCode)
                            .font(.system(.title2, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.15),
                                        in: RoundedRectangle(cornerRadius: 6))
                            .textSelection(.enabled)
                        CopyButton(text: userCode)
                    }
                }
            }

            ProgressView()
                .controlSize(.small)
                .padding(.top, 4)

            Spacer(minLength: 0)

            HStack {
                Button("Cancel", role: .cancel, action: onCancel)
                Spacer()
            }
        }
        .padding(16)
    }
}

private struct CopyButton: View {
    let text: String

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        } label: {
            Image(systemName: "doc.on.doc")
        }
        .buttonStyle(.borderless)
        .help("Copy")
    }
}
