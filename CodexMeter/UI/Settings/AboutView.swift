//
//  AboutView.swift
//  CodexMeter
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("CodexMeter")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Version \(Bundle.main.shortVersion ?? "0.1.0")")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Open-source macOS menu bar app for monitoring Codex usage. Runs locally, never stores OpenAI credentials.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension Bundle {
    var shortVersion: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
