//
//  PopoverView.swift
//  CodexMeter
//

import SwiftUI

struct PopoverView: View {
    @ObservedObject var appState: AppState
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            // Main phase content
            phaseView
                .opacity(showingSettings ? 0 : 1)

            if showingSettings {
                SettingsView(appState: appState, onDismiss: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showingSettings = false
                    }
                })
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: Constants.UI.popoverWidth, height: Constants.UI.popoverHeight)
        .animation(.easeInOut(duration: 0.25), value: showingSettings)
    }

    @ViewBuilder
    private var phaseView: some View {
        switch appState.phase {
        case .codexMissing:
            InstallCodexView(onRetry: appState.retryStartup)
        case .startup:
            StartupView()
        case .error(let reason):
            ErrorView(reason: reason, onRetry: appState.retryStartup)
        case .signedOut:
            SignedOutView(
                onSignInWithChatGPT: appState.startChatGPTLogin,
                onUseDeviceCode: appState.startDeviceCodeLogin
            )
        case .signingIn(let prompt):
            SigningInView(prompt: prompt, onCancel: appState.cancelCurrentLogin)
        case .ready:
            ReadyView(appState: appState, openSettings: openSettings)
        }
    }

    private func openSettings() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showingSettings = true
        }
    }
}

// MARK: - Ready view (signed in + showing data)

private struct ReadyView: View {
    @ObservedObject var appState: AppState
    var openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            if appState.snapshots.isEmpty {
                Text("No rate-limit data available for this account.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.snapshots) { snapshot in
                    BucketSection(snapshot: snapshot)
                }
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(16)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Usage").font(.headline)
                if let email = appState.account.displayEmail {
                    Text(email).font(.caption).foregroundStyle(.secondary)
                }
                if let plan = appState.account.displayPlan {
                    Text(plan.capitalized).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            ConnectionBadge(state: appState.connection)
        }
    }

    private var footer: some View {
        HStack {
            if let last = appState.lastUpdated {
                Text("Updated \(last.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                Task { await appState.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh")

            Button(action: openSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")

            Menu {
                Button("Sign out", action: appState.signOut)
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}

private struct ConnectionBadge: View {
    let state: ConnectionState

    var body: some View {
        let (label, color): (String, Color) = {
            switch state {
            case .connected:    return ("Connected", .green)
            case .connecting:   return ("Connecting", .yellow)
            case .disconnected: return ("Disconnected", .gray)
            case .failed:       return ("Error", .red)
            }
        }()
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct BucketSection: View {
    let snapshot: RateLimitSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot.limitName ?? snapshot.limitId?.capitalized ?? "Codex")
                .font(.subheadline)
                .fontWeight(.medium)

            if let primary = snapshot.primary {
                WindowRow(label: label(for: primary), window: primary)
            }
            if let secondary = snapshot.secondary {
                WindowRow(label: label(for: secondary), window: secondary)
            }

            if let reached = snapshot.rateLimitReachedType {
                Text(humanize(reached))
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private func label(for window: RateLimitWindow) -> String {
        switch window.windowDurationMins {
        case 300:    return "5-hour window"
        case 10080:  return "Weekly window"
        case let m?: return "\(m) min window"
        case nil:    return "Window"
        }
    }

    private func humanize(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private struct WindowRow: View {
    let label: String
    let window: RateLimitWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(window.usedPercent)%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ColorTheme.color(forUsage: Double(window.usedPercent)))
            }
            ProgressView(value: Double(window.usedPercent), total: 100)
                .tint(ColorTheme.color(forUsage: Double(window.usedPercent)))
            if let resetsAt = window.resetsAt {
                Text("Resets \(resetsAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
