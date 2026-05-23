//
//  PopoverView.swift
//  CodexMeter
//

import SwiftUI

struct PopoverView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            if appState.snapshots.isEmpty {
                emptyState
            } else {
                ForEach(appState.snapshots) { snapshot in
                    BucketSection(snapshot: snapshot)
                }
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(16)
        .frame(width: Constants.UI.popoverWidth, height: Constants.UI.popoverHeight)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Usage")
                    .font(.headline)
                if case .signedIn(let email, let plan, _) = appState.account {
                    Text(email ?? "Signed in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let plan {
                        Text(plan.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                } else if case .signedOut = appState.account {
                    Text("Not signed in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            connectionBadge
        }
    }

    private var connectionBadge: some View {
        let (label, color): (String, Color) = {
            switch appState.connection {
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

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No rate-limit data yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Phase 2 will populate this from `account/rateLimits/read`.")
                .font(.caption)
                .foregroundStyle(.tertiary)
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
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.small)
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
