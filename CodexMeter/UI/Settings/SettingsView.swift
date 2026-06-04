//
//  SettingsView.swift
//  CodexMeter
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            TabView {
                GeneralSettingsView(appState: appState)
                    .tabItem { Label("General", systemImage: "gearshape") }
                AppearanceSettingsView(appState: appState)
                    .tabItem { Label("Appearance", systemImage: "paintbrush") }
                NotificationSettingsView(appState: appState)
                    .tabItem { Label("Notifications", systemImage: "bell") }
                AboutView()
                    .tabItem { Label("About", systemImage: "info.circle") }
            }
            .padding(.top, 6)
        }
        .frame(width: Constants.UI.popoverWidth, height: Constants.UI.popoverHeight)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            Spacer()
            Text("Settings").font(.headline)
            Spacer()
            // Symmetric spacer for centering the title
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .hidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
