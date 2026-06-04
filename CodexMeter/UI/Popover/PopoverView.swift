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
                onUseDeviceCode: appState.startDeviceCodeLogin,
                onUseApiKey: appState.startApiKeyEntry
            )
        case .signingIn(let prompt):
            SigningInView(prompt: prompt, onCancel: appState.cancelCurrentLogin)
        case .apiKeyEntry(let state):
            ApiKeyEntryView(
                errorMessage: state.errorMessage,
                onCancel: appState.cancelApiKeyEntry,
                onSubmit: appState.submitApiKey
            )
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
        VStack(alignment: .leading, spacing: 12) {
            header
            if appState.snapshots.isEmpty {
                Text("No usage data yet for this account.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.snapshots) { snapshot in
                    if appState.settings.showFiveHourLimit, let primary = snapshot.primary {
                        LimitCard(title: "5-Hour Limit", window: primary)
                    }
                    if appState.settings.showWeeklyLimit, let secondary = snapshot.secondary {
                        LimitCard(title: "7-Day Limit", window: secondary)
                    }
                    if appState.settings.showCredits,
                       let credits = snapshot.credits,
                       credits.hasCredits {
                        CreditsCard(credits: credits)
                    }
                    if let reached = snapshot.rateLimitReachedType {
                        Text(humanize(reached))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(16)
    }

    private func humanize(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
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

private struct LimitCard: View {
    let title: String
    let window: RateLimitWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(window.displayedPercent)%")
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(color)
            }

            ProgressView(value: Double(window.displayedPercent), total: 100)
                .tint(color)
                .scaleEffect(x: 1, y: 1.3, anchor: .center)

            if let resetsAt = window.resetsAt {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                    Text("Resets: \(formattedDelta(to: resetsAt))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var color: Color {
        ColorTheme.color(forUsage: Double(window.displayedPercent))
    }

    /// "Resets: 4h 8m" for windows under a day, "Resets: 1d 16h" for longer.
    private func formattedDelta(to target: Date) -> String {
        let seconds = Int(max(0, target.timeIntervalSinceNow))
        if seconds < 60 { return "in less than a minute" }
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        if days >= 1 {
            let h = hours % 24
            return "\(days)d \(h)h"
        }
        let m = minutes % 60
        return "\(hours)h \(m)m"
    }
}

private struct CreditsCard: View {
    let credits: RateLimitCredits

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "creditcard")
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Credits")
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(amount)
                .font(.title3.monospacedDigit().weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var amount: String {
        if credits.unlimited { return "∞" }
        let trimmed = credits.balance.trimmingCharacters(in: .whitespaces)
        if let dollars = Double(trimmed) {
            return String(format: "$%.2f", dollars)
        }
        return trimmed.hasPrefix("$") ? trimmed : "$\(trimmed)"
    }

    private var subtitle: String {
        credits.unlimited ? "Unlimited" : "Available balance"
    }
}
